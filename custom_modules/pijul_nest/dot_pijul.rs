use crate::repository::{ChannelSpec, channel_spec};
use crate::{Config, Error};
use axum::{
    body::Body,
    extract::{Json, Path, Request, State},
    http::StatusCode,
    response::{IntoResponse, Response},
};
use futures::TryStreamExt;
use pijul_core::{Base32, ChannelTxnT, DepsTxnT, GraphTxnT, TxnT, TxnTExt};
use serde::*;
use std::collections::HashSet;
use tokio_util::io::ReaderStream;
use tracing::*;

#[derive(Debug, Deserialize)]
pub struct TreePath {
    pub owner: String,
    pub repo: String,
}

// 262kb at once.
const CHANGE_BUF_SIZE: usize = 1 << 18;

#[derive(Debug)]
enum Command {
    Changelist {
        from: u64,
        req_paths: Vec<String>,
    },
    State {
        at: Option<u64>,
    },
    Change {
        hash: pijul_core::pristine::Hash,
        full: bool,
        tag: bool,
    },
    Identities {
        from: Option<u64>,
    },
    Id,
}

#[axum::debug_handler]
pub async fn dot_pijul(
    State(config): State<Config>,
    Path(t): Path<TreePath>,
    req: Request,
) -> Result<Response, Error> {
    let mut db = config.db.get().await?;
    let (rid, uid, _) =
        super::repository_id(&mut db, &t.owner, &t.repo, None, super::Perm::READ).await?;
    let repo_id = crate::repository::RepositoryId {
        owner_id: uid,
        repo_id: rid,
        fork_origin: None,
    };

    debug!("repo = {:?}", repo_id);

    let mut command = None;
    let mut channel = ChannelSpec::Channel("main".to_string());
    if let Some(q) = req.uri().query() {
        let mut req_paths_ = Vec::new();
        for (k, v) in url::form_urlencoded::parse(q.as_bytes()) {
            debug!("{:?} {:?}", k, v);
            if k == "changelist" {
                if let Ok(from) = v.parse() {
                    command = Some(Command::Changelist {
                        from,
                        req_paths: Vec::new(),
                    })
                }
            } else if k == "path" {
                req_paths_.push(v.to_string());
            } else if k == "change" || k == "partial" || k == "tag" {
                if let Some(hash) = pijul_core::pristine::Hash::from_base32(v.as_bytes()) {
                    command = Some(Command::Change {
                        hash,
                        full: k == "change",
                        tag: k == "tag",
                    })
                }
            } else if k == "channel" {
                if let Some(cap) = crate::ssh::DISC.captures(&v) {
                    channel = ChannelSpec::Discussion(cap[1].parse().unwrap())
                } else {
                    channel = ChannelSpec::Channel(v.to_string())
                }
            } else if k == "state" {
                if let Ok(from) = v.parse() {
                    command = Some(Command::State { at: Some(from) })
                } else if v.is_empty() {
                    command = Some(Command::State { at: None })
                }
            } else if k == "identities" {
                if let Ok(from) = v.parse() {
                    command = Some(Command::Identities { from: Some(from) })
                } else if v.is_empty() {
                    command = Some(Command::Identities { from: None })
                }
            } else if k == "id" {
                command = Some(Command::Id)
            }
        }
        if let Some(Command::Changelist {
            ref mut req_paths, ..
        }) = command
        {
            *req_paths = req_paths_
        }
    }
    let is_default_channel = channel == ChannelSpec::Channel("main".to_string());
    debug!("command = {:?}", command);
    match command {
        Some(Command::Changelist { from, req_paths }) => match channel {
            ChannelSpec::Channel(channel) => {
                let repo_ = config.repo_locks.get(&rid).await?;
                let pristine = repo_.pristine.read().await;
                let txn = pristine.txn_begin()?;
                let c = channel_spec(&repo_id, &channel);
                let channel = if let Some(channel) = txn.load_channel(&c)? {
                    channel
                } else if is_default_channel {
                    return Ok(Json(()).into_response());
                } else {
                    debug!("channel not found {:?}", c);
                    return Ok((
                        StatusCode::NOT_FOUND,
                        Json(pijul_core::RemoteError::ChannelNotFound {
                            channel,
                            url: format!("{}/{}", t.owner, t.repo),
                        }),
                    )
                        .into_response());
                };
                use std::io::Write;
                let mut v = Vec::new();
                let mut paths = HashSet::new();
                for r in req_paths {
                    if let Ok((p, ambiguous)) = txn.follow_oldest_path(&repo_.changes, &channel, &r)
                    {
                        let h: pijul_core::Hash = txn.get_external(&p.change)?.unwrap().into();
                        writeln!(v, "{}.{}", h.to_base32(), p.pos.0)?;
                        if ambiguous {
                            let body =
                                serde_json::to_vec(&pijul_core::RemoteError::AmbiguousPath {
                                    path: r.to_string(),
                                })
                                .unwrap();
                            return Ok(hyper::Response::builder()
                                .status(hyper::StatusCode::NOT_FOUND)
                                .body(body.into())?);
                        }
                        paths.insert(p);
                        paths.extend(
                            pijul_core::fs::iter_graph_descendants(
                                &txn,
                                txn.graph(&*channel.read()),
                                p,
                            )?
                            .filter_map(|x| x.ok()),
                        );
                    } else {
                        let body = serde_json::to_vec(&pijul_core::RemoteError::PathNotFound {
                            path: r.to_string(),
                        })
                        .unwrap();
                        return Ok(hyper::Response::builder()
                            .status(hyper::StatusCode::NOT_FOUND)
                            .body(body.into())?);
                    }
                }
                debug!("paths = {:?}", paths);
                let tags: Vec<u64> = txn
                    .iter_tags(txn.tags(&*channel.read()), from)?
                    .map(|k| (*k.unwrap().0).into())
                    .collect();
                let mut tagsi = 0;
                for n in txn.log(&*channel.read(), from)? {
                    let (n, (h, m)) = n?;
                    let h_int = txn.get_internal(h)?.unwrap();
                    if paths.is_empty()
                        || paths.iter().any(|x| {
                            x.change == *h_int
                                || txn.get_touched_files(x, Some(h_int)).unwrap().is_some()
                        })
                    {
                        let h: pijul_core::Hash = h.into();
                        let m: pijul_core::Merkle = m.into();
                        if tags.get(tagsi) == Some(&n) {
                            writeln!(v, "{}.{}.{}.", n, h.to_base32(), m.to_base32())?;
                            tagsi += 1
                        } else {
                            writeln!(v, "{}.{}.{}", n, h.to_base32(), m.to_base32())?;
                        }
                    }
                }
                Ok(v.into_response())
            }
            ChannelSpec::Discussion(disc) => {
                let repo_ = config.repo_locks.get(&rid).await?;
                let body =
                    crate::discussions::discussion_changelist(&mut db, &repo_.changes, rid, disc)
                        .await?;
                Ok(body.into_response())
            }
        },
        Some(Command::Change { hash, full, tag }) => {
            let mut p = super::nest_changes_path(&config, rid);
            pijul_core::changestore::filesystem::push_filename(&mut p, &hash);
            debug!("{:?}", p);
            let file = match tokio::fs::File::open(&p).await {
                Ok(file) => file,
                Err(err) => {
                    return Ok(
                        (StatusCode::NOT_FOUND, format!("File not found: {}", err)).into_response()
                    );
                }
            };
            Ok(Body::from_stream(ReaderStream::new(file).into_stream()).into_response())
        }
        Some(Command::State { at }) => match channel {
            ChannelSpec::Channel(channel) => {
                let repo_ = config.repo_locks.get(&rid).await?;
                let pristine = repo_.pristine.read().await;
                let txn = pristine.txn_begin()?;
                let c = channel_spec(&repo_id, &channel);
                let channel = if let Some(channel) = txn.load_channel(&c)? {
                    channel
                } else {
                    debug!("channel not found {:?}", c);
                    let body = serde_json::to_vec(&pijul_core::RemoteError::ChannelNotFound {
                        channel,
                        url: format!("{}/{}", t.owner, t.repo),
                    })
                    .unwrap();
                    return Ok(hyper::Response::builder()
                        .status(hyper::StatusCode::NOT_FOUND)
                        .body(body.into())?);
                };
                let mut o = Vec::new();
                use std::io::Write;
                if let Some(n) = txn.reverse_log(&*channel.read(), at)?.next() {
                    let (n, (_, m)) = n?;
                    let m: pijul_core::Merkle = m.into();
                    writeln!(o, "{} {}", n, m.to_base32())?
                } else {
                    writeln!(o, "-")?;
                }
                debug!("body = {:?}", o);
                Ok(o.into_response())
            }
            ChannelSpec::Discussion(disc) => {
                let repo_ = config.repo_locks.get(&rid).await?;
                let (n, m) = crate::discussions::discussion_state(&mut db, rid, disc, at).await?;
                Ok(format!("{} {}\n", n, m.to_base32()).into_response())
            }
        },
        Some(Command::Identities { from }) => {
            /*
                let rows = if let Some(rev) = from {
                    self.db.query(
                        "SELECT login, email, name, revision, signingkeys.algorithm, signingkeys.public_key, signingkeys.signature, signingkeys.expires FROM contributors JOIN signingkeys ON signingkeys.public_key = contributors.key JOIN users ON user_id = users.id WHERE repo = $1 AND revision > $2",
                        &[
                            &repo.id.repo_id,
                            &(rev as i64)
                        ]).await?
                } else {
                    self.db.query(
                        "SELECT login, email, name, revision, signingkeys.algorithm, signingkeys.public_key, signingkeys.signature, signingkeys.expires FROM contributors JOIN signingkeys ON signingkeys.public_key = contributors.key JOIN users ON user_id = users.id WHERE repo = $1",
                        &[
                            &repo.id.repo_id,
                        ]).await?
            };
                */
            #[derive(Debug, Serialize)]
            struct Identities {
                id: Vec<super::Identity>,
                rev: u64,
            }
            let id = Identities {
                id: Vec::new(),
                rev: 0,
            };
            /*
                for r in rows {
                    let login: String = r.get(0);
                    let email: String = r.get(1);
                    let revision: chrono::DateTime<chrono::Utc> = r.get(3);
                    id.rev = id.rev.max(revision.timestamp() as u64);
                    let algorithm: crate::ssh::Keyalgorithm = r.get(4);
                    let key: Vec<u8> = r.get(5);
                    let signature: Vec<u8> = r.get(6);
                    let expires: Option<chrono::DateTime<chrono::Utc>> = r.get(7);
                    debug!("{:?} {:?}", key, login);
                    id.id.push(Identity {
                        public_key: pijul_core::key::PublicKey {
                            algorithm: algorithm.into(),
                            key: bs58::encode(&key).into_string(),
                            signature: bs58::encode(&signature).into_string(),
                            expires,
                            version: pijul_core::key::VERSION,
                        },
                        login,
                        email: Some(email),
                        origin: "nest.pijul.com".to_string(),
                        name: None,
                        last_modified: revision.timestamp() as u64,
                    })
            }
                */
            let body = serde_json::to_string_pretty(&id).unwrap();
            Ok((hyper::StatusCode::OK, Json(id)).into_response())
        }
        Some(Command::Id) => match channel {
            ChannelSpec::Channel(channel) => {
                let repo_ = config.repo_locks.get(&rid).await?;
                let pristine = repo_.pristine.read().await;
                let txn = pristine.txn_begin()?;
                let c = channel_spec(&repo_id, &channel);
                if let Some(channel) = txn.load_channel(&c)? {
                    let channel = channel.read();
                    Ok(format!("{}", channel.id).into_response())
                } else {
                    Ok((StatusCode::NOT_FOUND, b"Channel not found").into_response())
                }
            }
            _ => Ok(StatusCode::OK.into_response()),
        },
        None => Ok((StatusCode::NOT_FOUND, b"No command specified").into_response()),
    }
}
