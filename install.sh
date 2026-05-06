#!/usr/bin/env bash
set -euo pipefail

# Allow `source ./install.sh --source-only` for testing function bodies.
SOURCE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --source-only) SOURCE_ONLY=1 ;;
  esac
done

DAMSECURE_DIR="${DAMSECURE_INSTALL_DIR:-${HOME}/.damsecure/bin}"
LOCAL_BIN="${HOME}/.local/bin"
BINARY_NAME="damsecure"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# All status messages go to stderr so stdout is clean for command
# substitution (e.g., download_release returns the archive name on stdout).
info()  { printf "${GREEN}[INFO]${NC} %s\n"  "$1" >&2; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2; }
error() { printf "${RED}[ERROR]${NC} %s\n"   "$1" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    *)      error "Unsupported operating system: $(uname -s). Supported: macOS, Linux." ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)             error "Unsupported architecture: $(uname -m). Supported: x86_64, arm64." ;;
  esac
}

RELEASES_API="https://api.github.com/repos/dam-secure/cli/releases/latest"

resolve_version() {
  if [ -n "${DAMSECURE_VERSION:-}" ]; then
    echo "$DAMSECURE_VERSION"
    return 0
  fi
  local body tag
  body="$(curl -fsSL "$RELEASES_API")" || return 1
  tag="$(echo "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  if [ -z "$tag" ]; then
    error "Could not determine latest version from $RELEASES_API"
  fi
  echo "$tag"
}

sha256_tool() {
  if command -v sha256sum >/dev/null 2>&1; then echo sha256sum
  elif command -v shasum    >/dev/null 2>&1; then echo "shasum -a 256"
  else error "Need sha256sum or shasum on PATH."
  fi
}

verify_checksum() {
  local archive="$1" checksums="$2"
  if ! grep -q "[[:space:]]\+${archive}\$" "$checksums"; then
    error "Archive $archive not present in $checksums"
  fi
  local tool; tool="$(sha256_tool)"
  if ! grep "[[:space:]]\+${archive}\$" "$checksums" | $tool -c -; then
    error "Checksum verification failed for $archive"
  fi
}

install_binary() {
  local src="$1"
  if [ ! -f "$src" ] || [ ! -x "$src" ]; then
    error "Source binary $src missing or not executable"
  fi

  mkdir -p "$DAMSECURE_DIR" "$LOCAL_BIN"

  # Atomic in-place upgrade: copy to .new, then rename.
  cp "$src" "${DAMSECURE_DIR}/${BINARY_NAME}.new"
  chmod +x "${DAMSECURE_DIR}/${BINARY_NAME}.new"
  mv "${DAMSECURE_DIR}/${BINARY_NAME}.new" "${DAMSECURE_DIR}/${BINARY_NAME}"

  # Remove legacy /usr/local/bin install if present.
  if [ -f "/usr/local/bin/${BINARY_NAME}" ] || [ -L "/usr/local/bin/${BINARY_NAME}" ]; then
    rm -f "/usr/local/bin/${BINARY_NAME}" 2>/dev/null || sudo rm -f "/usr/local/bin/${BINARY_NAME}"
  fi

  ln -sf "${DAMSECURE_DIR}/${BINARY_NAME}" "${LOCAL_BIN}/${BINARY_NAME}"
}

warn_if_path_missing() {
  case ":${PATH}:" in
    *":${LOCAL_BIN}:"*) return 0 ;;
  esac
  warn "${LOCAL_BIN} is not on your PATH."
  echo ""
  info "Add this to your shell profile, then restart your terminal:"
  echo ""
  echo "  export PATH=\"${LOCAL_BIN}:\$PATH\""
  echo ""
}

RELEASE_BASE_URL_DEFAULT="https://github.com/dam-secure/cli/releases/download"

download_release() {
  local version="$1" os="$2" arch="$3" dest="$4"
  local archive="damsecure_${version}_${os}_${arch}.tar.gz"
  local base="${DAMSECURE_RELEASE_BASE_URL:-${RELEASE_BASE_URL_DEFAULT}/${version}}"

  info "Downloading ${archive} from ${base}"
  curl -fsSL --retry 1 --retry-delay 2 -o "${dest}/${archive}"     "${base}/${archive}"
  curl -fsSL --retry 1 --retry-delay 2 -o "${dest}/checksums.txt"  "${base}/checksums.txt"
  echo "${archive}"
}

extract_release() {
  local dest="$1" archive="$2"
  ( cd "$dest" && tar -xzf "$archive" )
  if [ ! -x "${dest}/${BINARY_NAME}" ]; then
    error "Archive did not contain an executable ${BINARY_NAME}"
  fi
}

interactive_setup() {
  if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
    info "CI environment detected — skipping interactive setup."
    return 0
  fi
  if [ "${DAMSECURE_SKIP_SETUP:-0}" = "1" ]; then
    info "DAMSECURE_SKIP_SETUP set — skipping interactive setup."
    return 0
  fi

  echo ""
  echo "Which editor are you using?"
  echo "  1) Claude"
  echo "  2) Cursor"
  printf "Enter 1 or 2: "
  read -r choice || true

  local platform
  case "${choice:-}" in
    1) platform="claude" ;;
    2) platform="cursor" ;;
    *) info "Skipping hook setup. Run 'damsecure setup claude' or 'damsecure setup cursor' later."; return 0 ;;
  esac

  if ! "${LOCAL_BIN}/${BINARY_NAME}" setup "$platform"; then
    warn "damsecure setup didn't finish cleanly. Run it again with: damsecure setup $platform"
    return 1
  fi
}

main() {
  info "Installing damsecure CLI..."

  local os arch version archive workdir
  os="${DAMSECURE_TEST_OS:-$(detect_os)}"
  arch="${DAMSECURE_TEST_ARCH:-$(detect_arch)}"
  info "Detected platform: ${os}/${arch}"

  version="$(resolve_version)"
  info "Installing version ${version}"

  workdir="$(mktemp -d)"
  # shellcheck disable=SC2064  # intentional eager-expansion: workdir is a local
  trap "rm -rf '$workdir'" EXIT

  archive="$(download_release "$version" "$os" "$arch" "$workdir")"
  ( cd "$workdir" && verify_checksum "$archive" checksums.txt )
  info "Verified ${archive}"

  extract_release "$workdir" "$archive"
  install_binary "${workdir}/${BINARY_NAME}"
  info "Installed to ${DAMSECURE_DIR}/${BINARY_NAME}"

  warn_if_path_missing
  interactive_setup
}

if [ "$SOURCE_ONLY" -eq 0 ]; then
  main "$@"
fi
