# rust-toolchain-cache

A tiny **public** cache for a Linux Rust toolchain, so ephemeral sandboxes can
get `cargo` by pulling a prebuilt tarball from a GitHub Release instead of
running `rustup` (and re-downloading `rust-std`) on every fresh environment.

Contains **only** the redistributable Rust toolchain (MIT/Apache) plus these
scripts. No proprietary code, no credentials.

## How it works

1. `.github/workflows/build-toolchain.yml` runs on a Linux runner, installs a
   minimal toolchain, tars it (`cargo/` + `rustup/`), and uploads it as a
   Release asset tagged by toolchain name (e.g. `stable`).
2. In a sandbox you source `scripts/bootstrap-cargo.sh`, which pulls that asset
   into a persistent `CARGO_HOME`/`RUSTUP_HOME` and puts `cargo` on `PATH`.
   It's idempotent and falls back to official rustup if no asset exists yet.

The default toolchain is pinned to **1.97.1** with **rustfmt + clippy** bundled,
matching `floodcaster-platform`'s `rust-toolchain.toml`, so its vendored build
runs fully offline (no component fetches on first use).

Each tag ships **two host variants** — `gnu` (glibc) and `musl` (Alpine/static) —
and every asset bundles **both** `x86_64-unknown-linux-gnu` and
`x86_64-unknown-linux-musl` std targets, so you can cross-compile to either libc
offline. The bootstrap auto-detects the sandbox's libc and pulls the matching
one; override with `RUST_LIBC=musl` (or `gnu`).

Assets per tag:

```
rust-<toolchain>-linux-x86_64-gnu.tar.zst
rust-<toolchain>-linux-x86_64-musl.tar.zst
```

> musl note: pure-Rust builds to `x86_64-unknown-linux-musl` link with the
> bundled self-contained linker and need nothing extra. Crates that link C still
> require a musl C toolchain (`musl-gcc`) in the sandbox — that's a sandbox
> concern, not part of this cache.

## Build the toolchain (once per version)

```bash
gh workflow run build-toolchain.yml -f toolchain=1.97.1
```

A scheduled run rebuilds the pinned default monthly (06:00 UTC, 1st of the
month) as a build canary — it verifies the rustup/Alpine/action toolchain still
works and keeps the release assets present. Trigger a specific version anytime
with the command above.

## Use it in the sandbox

```bash
# persist to a path that survives sandbox re-creation if you have one
RUST_CACHE_ROOT=/persist source scripts/bootstrap-cargo.sh   # pulls 1.97.1 by default
cargo --version
```

To use a different version, set `RUST_TOOLCHAIN` (and publish that tag first):

```bash
RUST_TOOLCHAIN=stable RUST_CACHE_ROOT=/persist source scripts/bootstrap-cargo.sh
```

For a supply-chain-frozen (vendored) project, this is all you need — once
`cargo` is present, the build resolves dependencies from the repo's `vendor/`
directory fully offline.
