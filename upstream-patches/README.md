# Upstream patch queue from the 2026-08-09 audit

These patches separate reusable packaging defects from this repository's local
policy. They are kept as standalone `patch -p1` candidates against the named
upstream source revisions.

## Configuration that must remain local

- Native x86_64 desktop outputs intentionally target AMD Zen 3 (`znver3`).
- Build-platform tools executed on that desktop may also use Zen 3.
- Foreign host/target outputs (notably aarch64 cross builds) must remain at their
  upstream baseline CPU and must never receive `target-cpu=znver3` or
  `-Dcpu=znver3`.
- CUDA capability 8.9 is host configuration, not a package default.

## Candidates

### `caldav-calendar-web-composable-overlay.patch`

Target: `DieracDelta/webdav-cal-simple` at
`fc56170b2a71e1bd7ccf774c3f9b8b81717621de`.

The current overlay returns `self.packages`, retaining the flake's independently
imported nixpkgs closure. The patch constructs the trivial static package with
the overlay consumer's `final` package set.

### `bpftop-configurable-module-package.patch`

Target: `DieracDelta/bpftop` at the revision locked by this repository.

The module hard-codes `self.packages`, preventing consumers from supplying a
package built by their configured package set. The patch adds the conventional
`programs.bpftop.package` option while preserving the current package as default.

### `rotki-pnpm10-fetcher.patch`

Target: the isolated Rotki 1.43.2 upgrade tree used by this repository.

The frontend installs pnpm 10 but lets `fetchPnpmDeps` default to pnpm 11 on
current nixpkgs. Passing `pnpm = pkgs.pnpm_10` makes fetcher version 3 coherent
and allows the flake's nixpkgs input to follow the system again. A second
upstream change is still needed to expose a `callPackage`-compatible package;
following the revision alone does not make Rotki's closed flake output share
the configured package set.

### `shapebpf-current-nixpkgs.patch`

Target: `DieracDelta/shapeBPF` at the revision locked by this repository.

The module's default package lookup uses deprecated `pkgs.system`. The package
also lets Cargo merge its workspace and eBPF vendor configurations; current
Cargo then rejects the duplicated Aya Git source. The patch uses the current
host-platform spelling and isolates the nested eBPF build's vendor source map.

### `nixpkgs-nodejs-24-brotli-backpressure.patch`

Target: nixpkgs at the revision locked by this repository.

Node.js 24.18.1 predates upstream Node PR 63389. Its Brotli 16 GB regression
test races a fixed 500 ms timeout against libuv worker-pool scheduling and
failed under the saturated, low-priority full desktop build after the other
4,950 test groups passed. The patch backports the accepted event-driven
upstream fix through nixpkgs' existing `fetchpatch2` convention; it does not
disable or deselect the test.

### `vimconfig-platform-and-current-aliases.patch`

Target: `DieracDelta/vimconfig` at the revision locked by this repository.

The flake uses the wrong `gcc.mtune` field, passes complete `-march` flags where
nixpkgs expects platform values, supplies a redundant same-system
`crossSystem`, and retains deprecated `pkgs.system` and `nixfmt-rfc-style`
aliases. The patch corrects those platform records and aliases while preserving
native Zen 3 and Apple M1 policy. The larger nvim-treesitter and package-factory
migrations remain separate work below.

## Nixpkgs candidate maintained in `~/nixpkgs`

- `nixpkgs-replace-stdenv-cross-overlays.patch`: forward
  `crossOverlays` through `config.replaceStdenv`. This is the exact small fix
  already present as `~/nixpkgs` commit `d9bb1cfa837d` (`stdenv: thread cross
  overlays through custom stdenv`) on `origin/uutils-coreutils-rebase`, but not
  yet in upstream master. The regression was introduced by nixpkgs commits
  `125de9a4c31a` and `b9e520627402` on 2026-06-06.

The former Sunshine patch is gone: locked nixpkgs already sets
`SYSTEMD_MODULES_LOAD_DIR`, and the stale patch only applied with fuzz. The
former global Rust patch is also gone: `env.NIX_RUSTFLAGS` in the configured
stdenv is nixpkgs' composable mechanism and correctly respects dependency
splicing.

## API changes still to prepare in their source repositories

- Psi should move its existing cross-aware `mkPsi` body into `nix/psi.nix`
  with formal dependencies and export an overlay using `final.callPackage`.
  The system-side implementation in this PR demonstrates the required
  build-host compiler and zlib splicing.
- Vimconfig should export `lib.mkNeovim { pkgs; ... }` or a composable overlay.
  Its current closed output is intentionally pinned for API compatibility and
  remains a duplicate generic package closure. It must also migrate from
  nixpkgs' deprecated `nvim-treesitter-legacy` interface before that becomes an
  evaluation error in 26.11. Its four internal `doCheck = false` sites also need
  individual upstream review rather than being inherited invisibly.
- Rotki should expose its backend/frontend through `callPackage`, then replace
  the machine-local path input with a clean Git revision. Its closed flake
  currently contains 26 `doCheck = false` sites and three runtime-dependency
  suppressions; those need a package-by-package upstream test audit.
- BPFTOP and shapeBPF should move their package bodies behind composable
  `callPackage` factories. Their nightly Rust requirements can then be passed
  explicitly while the rest of each dependency graph comes from the
  consumer's configured package set. shapeBPF also disables bpf-linker's test
  phase internally; BPFTOP has no explicit test suppression.
