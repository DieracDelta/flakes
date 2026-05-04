# Borg Backup: Plane + Forgejo

Encrypted, deduplicated, compressed backups of Plane and Forgejo to multiple
replicas, unlockable by any one of several independent keys.

## What gets backed up

- `/var/lib/forgejo` — git repos, LFS objects, config (excludes `/dump`)
- `/var/lib/plane` — uploads, secrets, storage
- `/var/backup/postgres/forgejo.sql.zst` — fresh pg_dump before each backup
- `/var/backup/postgres/plane.sql.zst` — fresh pg_dump before each backup

## Replicas

| Name | Location | Schedule |
|------|----------|----------|
| local | `/storage/backups/borg/forgejo-plane` | 04:00 daily |
| arm-vps | `ssh://borg@nixos-arm.tail5ca7.ts.net/./borg/desktop` | 04:30 daily |

Each replica is an independent Borg repo. Dedup operates within each repo
(not across them). If one corrupts, the other is unaffected.

Add more replicas by adding entries to `custom_modules.borgbackup.repos` in
`hosts/desktop.nixos.nix`.

## Encryption scheme

### Layer 1: Borg (data at rest)

Every chunk of backup data is encrypted with:
- **AES-256-CTR** — symmetric encryption, per-chunk nonce
- **BLAKE2b-256 MAC** — authentication on each encrypted chunk

The cipher and MAC are not configurable in Borg 1.x. `repokey-blake2` is the
strongest available mode.

Key hierarchy:
```
passphrase
  -> PBKDF2-HMAC-SHA256 (random salt, 100k+ iterations)
    -> passphrase-derived key
      -> decrypts master key (stored in repo, AES-256 wrapped)
        -> master key encrypts/authenticates all data chunks
```

The master key is generated once at `borg init`. Changing the passphrase
re-wraps the master key without re-encrypting data.

**Post-quantum**: AES-256 and BLAKE2b are quantum-safe. The symmetric layer
alone would survive Grover's algorithm (128-bit effective security).

### Layer 2: age (passphrase envelope)

The Borg passphrase is encrypted by `age` to multiple independent recipients.
**Any single one** can decrypt it:

| Recipient | Mechanism |
|-----------|-----------|
| Local age identity | X25519 key on desktop disk — used for daily automation |
| YubiKey 1 | `age-plugin-yubikey` — PIV slot, requires physical touch |
| YubiKey 2 | `age-plugin-yubikey` — independent PIV slot |
| MBP | age identity stored on the MacBook |
| Password | `age -p` passphrase recipient — same password in KeePassXC |

`age` uses **X25519** (Curve25519 ECDH) for key agreement and
**ChaCha20-Poly1305** for symmetric encryption of the passphrase.

**Post-quantum**: X25519 is broken by Shor's algorithm. This is the weak link.
At current data sensitivity levels and quantum computing timelines, this is
acceptable. age has no PQ mode yet.

### Why age (not GPG)

- Simple, small, auditable — one file format, no config, no key servers
- Multi-recipient is first-class (`-r KEY1 -r KEY2 -p`)
- `age-plugin-yubikey` covers hardware key enrollment
- GPG would cover the Trezor via `trezor-agent`, but GPG's complexity and
  attack surface aren't worth it for this use case

## Compression

`auto,zstd,22` — maximum zstd compression, applied per-chunk:

1. Borg tests a sample of each chunk for compressibility
2. Compressible data -> zstd level 22 (max)
3. Incompressible data (git pack files, images) -> stored raw

Compression happens **before** encryption (encrypted data won't compress).

Expected ratios for this data:
- SQL dumps: 5-10x
- Git loose objects: 2-4x
- Git pack files: ~1x (already compressed)
- Net: ~2 GB compressed from ~4 GB raw

## Deduplication

Borg splits files into variable-size chunks via **Buzhash** rolling hash
(content-defined chunking, ~512 KiB target). Chunk IDs are **keyed BLAKE2b**
hashes — keyed so an attacker can't fingerprint repo contents.

After the first full backup, daily incrementals store only changed chunks.
For mostly-static git repos, expect **tens of MB per daily backup**.

## Data pipeline

Per chunk, in order:
```
raw file data
  -> Buzhash content-defined chunking (~512 KiB target)
  -> keyed BLAKE2b chunk ID (dedup lookup)
  -> zstd level 22 (if compressible, else raw)
  -> AES-256-CTR + BLAKE2b-256 MAC
  -> written to repo
```

## Setup

Run the setup script once as root on the desktop:

```bash
sudo ./setup-borg-backup.sh
```

The script walks through five steps interactively:

### Step 1: SSH key

```bash
ssh-keygen -t ed25519 -f /root/.ssh/borg_ed25519 -N "" -C "borg@desktop"
```

**Why**: The remote borg job connects to the ARM VPS over SSH. A dedicated
key (not your user key) scoped to borg operations. The ARM VPS restricts
this key to `borg serve` via `services.borgbackup.repos` — it can only
read/write the borg repo, not get a shell.

After generating, paste the public key into
`hosts/nixos-arm.nixos.nix` `authorizedKeys` (replacing the TODO placeholder).

### Step 2: Local age identity

```bash
age-keygen -o /etc/borg/age-identity.txt
```

**Why**: This is the identity used for **daily automated decryption** of
the Borg passphrase. The systemd timer triggers the backup, the backup's
`passCommand` runs `age -d -i /etc/borg/age-identity.txt`, and the
passphrase is fed to Borg. No human interaction needed.

This key lives on the desktop's root filesystem. If disk encryption is
enabled, it's encrypted at rest. The age envelope adds defense-in-depth:
even if someone copies `/etc/borg/passphrase.age` off the machine, they
can't decrypt it without this identity (or one of the other recipients).

### Step 3: YubiKey enrollment

```bash
age-plugin-yubikey --generate > /etc/borg/yubikey1-identity.txt
```

**Why**: Recovery path. If the desktop dies and you lose the local age
identity, either YubiKey can independently decrypt the passphrase to
restore from the ARM VPS replica. The `--generate` command writes a new
key to the YubiKey's PIV slot and outputs an identity file referencing it.

The script prompts for slot, PIN policy, and touch policy. Recommended:
- Slot: 1 (or 2 for the second key — one slot per YubiKey)
- PIN policy: Once (enter PIN once per session)
- Touch policy: Always (physical touch required per decryption)

### Step 4: MBP key

On the MacBook:
```bash
age-keygen -o ~/borg-identity.txt
grep "public key:" ~/borg-identity.txt
```

Paste the public key into the setup script prompt.

**Why**: Another independent recovery path. If both YubiKeys and the
desktop are lost, the MBP can still decrypt the passphrase. Store the
identity file somewhere durable on the Mac (backed up by Time Machine, etc).

### Step 5: Passphrase generation + encryption

```bash
openssl rand -base64 32 > (passphrase)
age -r LOCAL_PUB -r YK1_PUB -r YK2_PUB -r MBP_PUB -p -o /etc/borg/passphrase.age
```

**Why**: `openssl rand -base64 32` produces 256 bits of entropy — the Borg
passphrase is a random string, not a human-memorable password. The `-p` flag
adds a password-based recipient: you type a password that `age` encrypts
the passphrase with independently. Store this same password in KeePassXC
as yet another recovery method.

The output `/etc/borg/passphrase.age` is a single file encrypted to all
recipients. Any one of them can decrypt it alone.

## After setup

### Deploy

```bash
# ARM VPS first (sets up the borg server user + SSH restriction)
# Then desktop
sudo nixos-rebuild switch --flake .#desktop
```

### Verify

The repos auto-initialize on the first timer trigger. To test immediately:

```bash
# Trigger manually
sudo systemctl start borgbackup-job-local.service

# Check status
sudo systemctl status borgbackup-job-local.service
sudo journalctl -u borgbackup-job-local.service -n 50

# List archives
sudo BORG_PASSCOMMAND="age -d -i /etc/borg/age-identity.txt /etc/borg/passphrase.age" \
  borg list /storage/backups/borg/forgejo-plane
```

### Restore

```bash
# List archives
sudo BORG_PASSCOMMAND="age -d -i /etc/borg/age-identity.txt /etc/borg/passphrase.age" \
  borg list /storage/backups/borg/forgejo-plane

# Extract a specific archive to current directory
sudo BORG_PASSCOMMAND="age -d -i /etc/borg/age-identity.txt /etc/borg/passphrase.age" \
  borg extract /storage/backups/borg/forgejo-plane::ARCHIVE_NAME

# Restore just the database dumps
sudo BORG_PASSCOMMAND="age -d -i /etc/borg/age-identity.txt /etc/borg/passphrase.age" \
  borg extract /storage/backups/borg/forgejo-plane::ARCHIVE_NAME var/backup/postgres

# Restore database from dump
zstd -d < var/backup/postgres/forgejo.sql.zst | sudo -u postgres psql forgejo
```

### Disaster recovery (desktop is gone)

If you only have a YubiKey:
```bash
age -d -i /etc/borg/yubikey1-identity.txt /etc/borg/passphrase.age
```

If you only have the KeePassXC password:
```bash
age -d -p /etc/borg/passphrase.age
# type the password
```

If you only have the MBP:
```bash
age -d -i ~/borg-identity.txt /path/to/passphrase.age
```

Any of these gives you the Borg passphrase. Then:
```bash
export BORG_PASSPHRASE="the-passphrase"
borg list ssh://borg@nixos-arm.tail5ca7.ts.net/./borg/desktop
borg extract ssh://borg@nixos-arm.tail5ca7.ts.net/./borg/desktop::ARCHIVE_NAME
```

### Adding a recipient later

If you get a new hardware key or want to add another recovery path:

```bash
# Decrypt the passphrase with any existing method
PASSPHRASE=$(age -d -i /etc/borg/age-identity.txt /etc/borg/passphrase.age)

# Re-encrypt to all recipients (old + new)
echo "$PASSPHRASE" | age \
  -r OLD_RECIPIENT_1 -r OLD_RECIPIENT_2 -r NEW_RECIPIENT -p \
  -o /etc/borg/passphrase.age
```

### Pruning / retention

Default retention (configurable in `custom_modules.borgbackup.prune`):

| Keep | Count |
|------|-------|
| Daily | 7 |
| Weekly | 4 |
| Monthly | 6 |

Borg prunes automatically after each backup. Old archives are removed but
deduplicated chunks still referenced by kept archives are preserved.

## Files reference

| File | Purpose | Sensitive |
|------|---------|-----------|
| `/etc/borg/age-identity.txt` | Local age private key (daily automation) | Yes |
| `/etc/borg/passphrase.age` | Encrypted Borg passphrase | No (encrypted) |
| `/etc/borg/yubikey1-identity.txt` | YubiKey 1 identity (references PIV slot) | Low (useless without the YubiKey) |
| `/etc/borg/yubikey2-identity.txt` | YubiKey 2 identity | Low |
| `/root/.ssh/borg_ed25519` | SSH key for remote repo transport | Yes |
| `/var/backup/postgres/*.sql.zst` | Pre-backup database dumps | Yes (transient) |

## NixOS module files

| File | What it does |
|------|-------------|
| `custom_modules/borgbackup.nix` | Backup client module (jobs, init services, packages) |
| `hosts/desktop.nixos.nix` | Enables module, defines repos |
| `hosts/nixos-arm.nixos.nix` | Borg server (restricted SSH user + repo path) |
| `setup-borg-backup.sh` | One-time interactive setup script |
