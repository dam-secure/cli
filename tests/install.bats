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
