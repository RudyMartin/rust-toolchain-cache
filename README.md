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

## Build the toolchain (once per version)

```bash
gh workflow run build-toolchain.yml -f toolchain=stable
```

## Use it in the sandbox

```bash
# persist to a path that survives sandbox re-creation if you have one
RUST_CACHE_ROOT=/persist source scripts/bootstrap-cargo.sh
cargo --version
```

For a supply-chain-frozen (vendored) project, this is all you need — once
`cargo` is present, the build resolves dependencies from the repo's `vendor/`
directory fully offline.
