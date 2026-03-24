# Secret References

This directory is the source of truth for runtime secret wiring.

- `refs/common.env` contains secret references shared across contexts.
- `refs/mac.env` contains secret references that require your interactive macOS 1Password session.
- `refs/vm.env` contains secret references available to the headless VM service account.

Rules:

- Commit only `op://...` references here, never plaintext secrets.
- Render secret-backed runtime configs with `./scripts/render-secret-configs.sh`.
- Run commands with secret-backed environment variables through `./scripts/with-secrets.sh`.
- For GitHub Packages auth, use the repo-managed `~/.npmrc` plus `~/.local/bin/pnpm` wrapper instead of exporting `GH_NPM_TOKEN` in shell startup files.
- Add new secret references here first, then wire them into templates or wrappers.
