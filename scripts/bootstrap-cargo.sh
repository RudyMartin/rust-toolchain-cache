#!/usr/bin/env bash
# Provision a Linux Rust toolchain into a persistent CARGO_HOME/RUSTUP_HOME by
# pulling a prebuilt release tarball from this repo, falling back to rustup.
#
# Usage (inside the Linux sandbox):
#   RUST_CACHE_ROOT=/persist source scripts/bootstrap-cargo.sh
#
# Idempotent: if cargo is already present in CARGO_HOME it does nothing.
# Source this file (do not execute) so the exported vars reach your shell.

_rtc_root="${RUST_CACHE_ROOT:-$HOME/.rust-cache}"
export CARGO_HOME="${CARGO_HOME:-$_rtc_root/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$_rtc_root/rustup}"
_rtc_toolchain="${RUST_TOOLCHAIN:-1.97.1}"
_rtc_repo="${TOOLCHAIN_REPO:-RudyMartin/rust-toolchain-cache}"

# Detect the sandbox's libc so we pull a runnable toolchain (musl-linked cargo
# will not run on a glibc host and vice versa). Override with RUST_LIBC.
if [ -n "${RUST_LIBC:-}" ]; then
  _rtc_libc="$RUST_LIBC"
elif ls /lib/ld-musl-*.so.1 >/dev/null 2>&1 || { command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; }; then
  _rtc_libc="musl"
else
  _rtc_libc="gnu"
fi

if [ -x "$CARGO_HOME/bin/cargo" ]; then
  printf 'cargo already provisioned: %s\n' "$("$CARGO_HOME/bin/cargo" --version)"
else
  mkdir -p "$_rtc_root"
  _rtc_asset="https://github.com/$_rtc_repo/releases/download/$_rtc_toolchain/rust-$_rtc_toolchain-linux-x86_64-$_rtc_libc.tar.zst"
  _rtc_tmp="$(mktemp "${TMPDIR:-/tmp}/rust-tc.XXXXXX")"
  # Fast path (prebuilt tarball) only when CARGO_HOME/RUSTUP_HOME are at their
  # default locations under RUST_CACHE_ROOT, since the tarball extracts to
  # $_rtc_root/{cargo,rustup}. Otherwise fall through to rustup, which honors a
  # custom CARGO_HOME/RUSTUP_HOME.
  if [ "$CARGO_HOME" = "$_rtc_root/cargo" ] && [ "$RUSTUP_HOME" = "$_rtc_root/rustup" ] \
     && curl -fsSL "$_rtc_asset" -o "$_rtc_tmp"; then
    # Tarball root contains cargo/ and rustup/ directories.
    tar -x --zstd -C "$_rtc_root" -f "$_rtc_tmp"
    printf 'provisioned from release: %s\n' "$_rtc_asset"
  else
    printf 'using rustup (custom paths or asset unavailable)...\n' >&2
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-host "x86_64-unknown-linux-$_rtc_libc" \
          --default-toolchain "$_rtc_toolchain" --profile minimal \
          --component rustfmt --component clippy --no-modify-path
  fi
  rm -f "$_rtc_tmp"
fi

case ":${PATH}:" in
  *":$CARGO_HOME/bin:"*) ;;
  *) export PATH="$CARGO_HOME/bin:$PATH" ;;
esac

if [ -x "$CARGO_HOME/bin/cargo" ]; then
  printf 'cargo ready: %s\n' "$("$CARGO_HOME/bin/cargo" --version)"
  _rtc_status=0
else
  printf 'cargo could not be provisioned\n' >&2
  _rtc_status=1
fi

unset _rtc_root _rtc_toolchain _rtc_repo _rtc_asset _rtc_libc _rtc_tmp
return "$_rtc_status" 2>/dev/null || exit "$_rtc_status"
