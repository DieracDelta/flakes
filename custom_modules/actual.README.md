# Actual Budget Setup

Personal finance manager with SimpleFIN bank sync.

## Auth Setup (Required Before First Deploy)

Actual is protected by Caddy basic auth. You must create the auth file before enabling.

### 1. Create directory
```bash
sudo mkdir -p /var/lib/actual
```

### 2. Generate password hash
```bash
caddy hash-password
```
Enter your password when prompted. Copy the output (starts with `$2a$14$...`).

### 3. Create auth file
```bash
sudo tee /var/lib/caddy/actual-auth << 'EOF'
basic_auth {
    jrestivo $YOUR_HASH_HERE
}
EOF
```

### 4. Secure the file
```bash
sudo chown caddy:caddy /var/lib/caddy/actual-auth
sudo chmod 640 /var/lib/caddy/actual-auth
```

## Access

- URL: `https://office-desktop.tail5ca7.ts.net:5007/`
- Auth: Caddy basic auth (credentials from above)
- Budget password: Set on first run in Actual UI

Note: Actual Budget doesn't support subpath mounting, so it runs on a separate port.

## SimpleFIN Setup

1. Go to https://beta-bridge.simplefin.org
2. Sign up ($15/year)
3. Link your banks: Chase, Discover, Bilt, Santander, Wells Fargo, Fidelity, Raisin
4. Get your SimpleFIN access token
5. In Actual: Settings → Show advanced settings → Link bank account with SimpleFIN
6. Paste token and link accounts

## Data Location

- Budget files: `/var/lib/actual/user-files/`
- Server data: `/var/lib/actual/server-files/`
- Auth file: `/var/lib/caddy/actual-auth`

## Ports

- Internal: 5006
- External: 5007 (via Caddy with TLS)
