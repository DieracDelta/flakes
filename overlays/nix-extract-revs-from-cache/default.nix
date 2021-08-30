# thank you Max : D : D
{jq, sqlite, writeShellScript}:
writeShellScript "nix-extract-revs-from-cache" ''
  info() {
    label=$1;shift
    echo -e "\033[0;33mdebug [$label]" "$@"'\033[0m'  >&2
  }
  sql() {
    info sql querying: "$@"
    echo "$@" | ${sqlite}/bin/sqlite3 ~/.cache/nix/fetcher-cache-v1.sqlite
  }
  read -r type repo <<<$(nix flake metadata $1 --json | ${jq}/bin/jq -r '"\(.resolved.type) \(.resolved.owner)/\(.resolved.repo)"')
  info flake type: $type repo: $repo
  case $type in
    github)
      echo available revs for this flake:
      sql 'select input from Cache where input like "%https://api.github.com/repos/'"$repo"'/tarball/%";' \
        | ${jq}/bin/jq -r '.url' | rev | cut -d/ -f1 | rev | sort -u
      ;;
    *)
      echo error: fetcher type $type not implemented
      ;;
  esac
''
