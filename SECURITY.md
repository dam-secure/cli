# Security

## Reporting a vulnerability

Email `security@damsecure.ai` with details. Do not file a public issue.

## Verifying a release manually

Each release publishes the binaries plus a `checksums.txt` containing SHA-256 hashes.

    # Replace <ver> and <os>/<arch> with your target.
    ARCHIVE="damsecure_<ver>_<os>_<arch>.tar.gz"
    RELEASE_URL="https://github.com/dam-secure/cli/releases/download/<ver>"

    curl -fsSL -o "$ARCHIVE"            "$RELEASE_URL/$ARCHIVE"
    curl -fsSL -o checksums.txt         "$RELEASE_URL/checksums.txt"

    # macOS
    shasum -a 256 -c <(grep "$ARCHIVE" checksums.txt)
    # Linux
    sha256sum -c <(grep "$ARCHIVE" checksums.txt)

Expected output: `damsecure_<ver>_<os>_<arch>.tar.gz: OK`.
