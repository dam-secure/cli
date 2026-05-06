#!/usr/bin/env bats

load test_helper

setup()    { setup_install_env; }
teardown() { teardown_install_env; }

@test "detect_os returns darwin on macOS" {
  source ./install.sh --source-only
  uname() { echo "Darwin"; }
  export -f uname
  run detect_os
  [ "$status" -eq 0 ]
  [ "$output" = "darwin" ]
}

@test "detect_os returns linux on Linux" {
  source ./install.sh --source-only
  uname() { echo "Linux"; }
  export -f uname
  run detect_os
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
}

@test "detect_os errors on FreeBSD" {
  source ./install.sh --source-only
  uname() { echo "FreeBSD"; }
  export -f uname
  run detect_os
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported"* ]]
}

@test "detect_arch maps x86_64 to amd64" {
  source ./install.sh --source-only
  uname() { echo "x86_64"; }
  export -f uname
  run detect_arch
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]
}

@test "detect_arch maps arm64 to arm64" {
  source ./install.sh --source-only
  uname() { echo "arm64"; }
  export -f uname
  run detect_arch
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

@test "detect_arch maps aarch64 to arm64" {
  source ./install.sh --source-only
  uname() { echo "aarch64"; }
  export -f uname
  run detect_arch
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

@test "detect_arch errors on i386" {
  source ./install.sh --source-only
  uname() { echo "i386"; }
  export -f uname
  run detect_arch
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported"* ]]
}

@test "resolve_version honors DAMSECURE_VERSION env" {
  source ./install.sh --source-only
  DAMSECURE_VERSION="v1.2.3"
  run resolve_version
  [ "$status" -eq 0 ]
  [ "$output" = "v1.2.3" ]
}

@test "resolve_version queries GitHub when DAMSECURE_VERSION unset" {
  source ./install.sh --source-only
  unset DAMSECURE_VERSION
  curl() { echo '{"tag_name":"v9.9.9","name":"damsecure 9.9.9"}'; }
  export -f curl
  run resolve_version
  [ "$status" -eq 0 ]
  [ "$output" = "v9.9.9" ]
}

@test "resolve_version errors when GitHub returns no tag_name" {
  source ./install.sh --source-only
  unset DAMSECURE_VERSION
  curl() { echo '{"message":"Not Found"}'; }
  export -f curl
  run resolve_version
  [ "$status" -ne 0 ]
}

@test "verify_checksum passes for matching archive" {
  source ./install.sh --source-only
  cp tests/fixtures/damsecure_v0.1.0_linux_amd64.tar.gz "$TEST_TMPDIR/"
  cp tests/fixtures/checksums.txt "$TEST_TMPDIR/"
  pushd "$TEST_TMPDIR" >/dev/null
  run verify_checksum damsecure_v0.1.0_linux_amd64.tar.gz checksums.txt
  popd >/dev/null
  [ "$status" -eq 0 ]
}

@test "verify_checksum fails when archive is tampered" {
  source ./install.sh --source-only
  cp tests/fixtures/damsecure_v0.1.0_linux_amd64.tar.gz "$TEST_TMPDIR/"
  cp tests/fixtures/checksums.txt "$TEST_TMPDIR/"
  echo "tampered" >> "$TEST_TMPDIR/damsecure_v0.1.0_linux_amd64.tar.gz"
  pushd "$TEST_TMPDIR" >/dev/null
  run verify_checksum damsecure_v0.1.0_linux_amd64.tar.gz checksums.txt
  popd >/dev/null
  [ "$status" -ne 0 ]
}

@test "verify_checksum fails when archive is missing from checksums.txt" {
  source ./install.sh --source-only
  cp tests/fixtures/damsecure_v0.1.0_linux_amd64.tar.gz "$TEST_TMPDIR/"
  echo "deadbeef  some_other_archive.tar.gz" > "$TEST_TMPDIR/checksums.txt"
  pushd "$TEST_TMPDIR" >/dev/null
  run verify_checksum damsecure_v0.1.0_linux_amd64.tar.gz checksums.txt
  popd >/dev/null
  [ "$status" -ne 0 ]
}

@test "install_binary places binary and creates symlink" {
  source ./install.sh --source-only
  echo "fake bin" > "$TEST_TMPDIR/damsecure"
  chmod +x "$TEST_TMPDIR/damsecure"
  run install_binary "$TEST_TMPDIR/damsecure"
  [ "$status" -eq 0 ]
  [ -x "$HOME/.damsecure/bin/damsecure" ]
  [ -L "$HOME/.local/bin/damsecure" ]
  [ "$(readlink "$HOME/.local/bin/damsecure")" = "$HOME/.damsecure/bin/damsecure" ]
}

@test "install_binary is idempotent" {
  source ./install.sh --source-only
  echo "v1" > "$TEST_TMPDIR/damsecure"
  chmod +x "$TEST_TMPDIR/damsecure"
  run install_binary "$TEST_TMPDIR/damsecure"
  [ "$status" -eq 0 ]
  echo "v2" > "$TEST_TMPDIR/damsecure"
  chmod +x "$TEST_TMPDIR/damsecure"
  run install_binary "$TEST_TMPDIR/damsecure"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.damsecure/bin/damsecure")" = "v2" ]
}

@test "install_binary atomic: pre-existing target survives a failed move" {
  source ./install.sh --source-only
  mkdir -p "$HOME/.damsecure/bin"
  echo "OLD" > "$HOME/.damsecure/bin/damsecure"
  chmod +x "$HOME/.damsecure/bin/damsecure"
  # Source path doesn't exist — install_binary must fail without clobbering.
  run install_binary "$TEST_TMPDIR/nonexistent"
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.damsecure/bin/damsecure")" = "OLD" ]
}

@test "warn_if_path_missing prints when ~/.local/bin not on PATH" {
  source ./install.sh --source-only
  PATH="/usr/bin:/bin"
  run warn_if_path_missing
  [ "$status" -eq 0 ]
  [[ "$output" == *".local/bin"* ]]
}

@test "warn_if_path_missing silent when ~/.local/bin on PATH" {
  source ./install.sh --source-only
  PATH="$HOME/.local/bin:/usr/bin:/bin"
  run warn_if_path_missing
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
