#!/usr/bin/env bash

set -e

REPO_DIR=$(git rev-parse --show-toplevel)

# shellcheck source=./fuzz-util.sh
source "$REPO_DIR/fuzz/fuzz-util.sh"

# 1. Generate fuzz/Cargo.toml
cat > "$REPO_DIR/fuzz/Cargo.toml" <<EOF
[package]
name = "hex-fuzz"
$(grep '^edition ' "$REPO_DIR/Cargo.toml")
$(grep '^rust-version ' "$REPO_DIR/Cargo.toml")
version = "0.0.1"
authors = ["Generated by fuzz/generate-files.sh"]
publish = false

[package.metadata]
cargo-fuzz = true

[dependencies]
honggfuzz = { version = "0.5.56", default-features = false }
hex = { path = "..", package = "hex-conservative" }
EOF

for targetFile in $(listTargetFiles); do
    targetName=$(targetFileToName "$targetFile")
    cat >> "$REPO_DIR/fuzz/Cargo.toml" <<EOF

[[bin]]
name = "$targetName"
path = "$targetFile"
EOF
done

cat >> "$REPO_DIR/fuzz/Cargo.toml" <<EOF

[lints.rust]
unexpected_cfgs = { level = "deny", check-cfg = ['cfg(fuzzing)'] }
EOF

# 2. Generate .github/workflows/fuzz.yml
cat > "$REPO_DIR/.github/workflows/cron-daily-fuzz.yml" <<EOF
# Automatically generated by fuzz/generate-files.sh
name: Fuzz
on:
  schedule:
    # 5am every day UTC, this correlates to:
    # - 10pm PDT
    # - 6am CET
    # - 4pm AEDT
    - cron: '00 05 * * *'

jobs:
  fuzz:
    if: \${{ !github.event.act }}
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        # We only get 20 jobs at a time, we probably don't want to go
        # over that limit with fuzzing because of the hour run time.
        fuzz_target: [
$(for name in $(listTargetNames); do echo "$name,"; done)
        ]
    steps:
      - name: Install test dependencies
        run: sudo apt-get update -y && sudo apt-get install -y binutils-dev libunwind8-dev libcurl4-openssl-dev libelf-dev libdw-dev cmake gcc libiberty-dev
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        id: cache-fuzz
        with:
          path: |
            ~/.cargo/bin
            fuzz/target
            target
          key: cache-\${{ matrix.target }}-\${{ hashFiles('**/Cargo.toml','**/Cargo.lock') }}
      - uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: '1.65.0'
      - name: fuzz
        run: cd fuzz && ./fuzz.sh "\${{ matrix.fuzz_target }}"
      - run: echo "\${{ matrix.fuzz_target }}" >executed_\${{ matrix.fuzz_target }}
      - uses: actions/upload-artifact@v4
        with:
          name: executed_\${{ matrix.fuzz_target }}
          path: executed_\${{ matrix.fuzz_target }}

  verify-execution:
    if: \${{ !github.event.act }}
    needs: fuzz
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
      - name: Display structure of downloaded files
        run: ls -R
      - run: find executed_* -type f -exec cat {} + | sort > executed
      - run: source ./fuzz/fuzz-util.sh && listTargetNames | sort | diff - executed
EOF

