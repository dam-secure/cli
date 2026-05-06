# damsecure CLI

The `damsecure` CLI brings the [damsecure](https://damsecure.ai) security layer to your editor.

## Install

    curl https://raw.githubusercontent.com/dam-secure/cli/main/install.sh | sh

Supported on macOS and Linux (amd64 + arm64). The installer:

- Downloads the matching prebuilt binary from this repo's [Releases](https://github.com/dam-secure/cli/releases).
- Verifies the SHA-256 checksum.
- Installs to `~/.damsecure/bin/damsecure` and symlinks `~/.local/bin/damsecure`.
- Prompts you to authenticate and configure your editor (Claude or Cursor).

## Pinning a specific version

    DAMSECURE_VERSION=v0.1.0 curl https://raw.githubusercontent.com/dam-secure/cli/main/install.sh | sh

## Manually verifying a release

See [SECURITY.md](./SECURITY.md) for the exact checksum-verification commands.

## Reporting vulnerabilities

See [SECURITY.md](./SECURITY.md).

## License

See [LICENSE](./LICENSE).
