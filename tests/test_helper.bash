# Common test setup. Sourced from each .bats file.

setup_install_env() {
  TEST_TMPDIR="$(mktemp -d)"
  export HOME="$TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export PATH="$TEST_TMPDIR/bin:$PATH"
  mkdir -p "$TEST_TMPDIR/bin"
}

teardown_install_env() {
  rm -rf "$TEST_TMPDIR"
}

# Stub a binary that records its args + always exits 0 (or a chosen code).
stub_command() {
  local name="$1" exit_code="${2:-0}"
  cat > "$TEST_TMPDIR/bin/$name" <<EOF
#!/usr/bin/env bash
echo "$name \$*" >> "$TEST_TMPDIR/calls.log"
exit $exit_code
EOF
  chmod +x "$TEST_TMPDIR/bin/$name"
}
