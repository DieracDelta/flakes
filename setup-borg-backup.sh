#!/usr/bin/env bash
# One-time setup for encrypted Borg backups of Plane + Forgejo.
# Run as root on the desktop.
set -euo pipefail

BORG_DIR="/etc/borg"
SSH_KEY="/root/.ssh/borg_ed25519"

echo "=== Borg Backup Setup ==="
echo ""

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root"
  exit 1
fi

for cmd in age ssh-keygen openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd not found. Run: nix-shell -p age openssl openssh"
    exit 1
  fi
done

mkdir -p "$BORG_DIR"
chmod 700 "$BORG_DIR"

RECIPIENTS=()

# --- Step 1: SSH key for remote borg repos ---
echo "--- Step 1/5: SSH key ---"
if [ -f "$SSH_KEY" ]; then
  echo "Already exists: $SSH_KEY"
else
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "borg@desktop"
fi
echo ""
echo "Public key (paste into hosts/nixos-arm.nixos.nix authorizedKeys):"
echo ""
echo "  $(cat "${SSH_KEY}.pub")"
echo ""

# --- Step 2: Local age identity for daily automation ---
echo "--- Step 2/5: Local age identity ---"
if [ -f "$BORG_DIR/age-identity.txt" ]; then
  echo "Already exists: $BORG_DIR/age-identity.txt"
else
  age-keygen -o "$BORG_DIR/age-identity.txt" 2>&1
fi
LOCAL_PUB=$(grep "public key:" "$BORG_DIR/age-identity.txt" | awk '{print $NF}')
RECIPIENTS+=("-r" "$LOCAL_PUB")
echo "Local recipient: $LOCAL_PUB"
echo ""

# --- Step 3: YubiKey enrollment ---
echo "--- Step 3/5: YubiKey enrollment ---"
if command -v age-plugin-yubikey &>/dev/null; then
  for i in 1 2; do
    read -rp "Enroll YubiKey $i? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      echo "Insert YubiKey $i and press Enter..."
      read -r
      YKFILE="$BORG_DIR/yubikey${i}-identity.txt"
      age-plugin-yubikey --generate > "$YKFILE"
      YK_RECIP=$(grep "^# recipient:" "$YKFILE" | sed 's/^# recipient: //' || \
                 grep "^# Recipient:" "$YKFILE" | sed 's/^# Recipient: //' || true)
      if [ -n "$YK_RECIP" ]; then
        RECIPIENTS+=("-r" "$YK_RECIP")
        echo "YubiKey $i enrolled: $YK_RECIP"
      else
        echo "Warning: could not extract recipient from YubiKey $i output"
        echo "Check $YKFILE and add the recipient manually"
      fi
      echo ""
    fi
  done
else
  echo "age-plugin-yubikey not found — skipping"
  echo "Install it and re-run to add YubiKey recipients later"
  echo ""
fi

# --- Step 4: MBP key ---
echo "--- Step 4/5: MacBook Pro age key ---"
echo "On the MBP, run:"
echo "  age-keygen -o ~/borg-identity.txt"
echo "  grep 'public key:' ~/borg-identity.txt"
echo ""
read -rp "Paste MBP public key (Enter to skip): " MBP_PUB
if [ -n "$MBP_PUB" ]; then
  RECIPIENTS+=("-r" "$MBP_PUB")
  echo "MBP key added"
fi
echo ""

# --- Step 5: Generate passphrase + encrypt to all recipients ---
echo "--- Step 5/5: Generate and encrypt Borg passphrase ---"
PASSPHRASE=$(openssl rand -base64 32)

echo ""
echo "Encrypting to ${#RECIPIENTS[@]} key recipients + a recovery password."
echo ""
echo "You will be prompted for a recovery PASSWORD."
echo "This is a standalone unlock method — store it in KeePassXC too."
echo ""
echo "$PASSPHRASE" | age "${RECIPIENTS[@]}" -p -o "$BORG_DIR/passphrase.age"

chmod 600 "$BORG_DIR"/*

echo ""
echo "=== Setup complete ==="
echo ""
echo "Files:"
echo "  $SSH_KEY                        SSH private key (remote transport)"
echo "  ${SSH_KEY}.pub                   SSH public key (add to ARM VPS)"
echo "  $BORG_DIR/age-identity.txt       Local age identity (daily automation)"
echo "  $BORG_DIR/passphrase.age         Encrypted Borg passphrase"
ls "$BORG_DIR"/yubikey*-identity.txt 2>/dev/null && \
echo "  $BORG_DIR/yubikey*-identity.txt  YubiKey recovery identities"
echo ""
echo "=== SAVE THIS PASSPHRASE — it will not be shown again ==="
echo ""
echo "  $PASSPHRASE"
echo ""
echo "Store it in KeePassXC as a backup unlock method."
echo ""
echo "Next steps:"
echo "  1. Paste SSH pubkey into hosts/nixos-arm.nixos.nix authorizedKeys"
echo "  2. Deploy ARM VPS"
echo "  3. Deploy desktop: sudo nixos-rebuild switch --flake .#desktop"
echo "  4. Repos auto-initialize on first backup timer trigger"
