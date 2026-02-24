{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/opencode.nix
  ];

  services.opencode.server.enable = true;

  # Give caddy permission to bind to low ports (80, 443) without root.
  # Nix store is read-only, so we copy the binary and apply the capability.
  home.activation.caddySetcap = lib.hm.dag.entryAfter ["installPackages"] ''
    CADDY_SRC="${pkgs.caddy}/bin/caddy"
    CADDY_DST="$HOME/.local/bin/caddy"
    # Re-copy if nix caddy was updated or local copy is missing
    if [ ! -f "$CADDY_DST" ] || [ "$(readlink -f "$CADDY_SRC")" != "$(cat "$CADDY_DST.src" 2>/dev/null)" ]; then
      $DRY_RUN_CMD cp "$CADDY_SRC" "$CADDY_DST"
      $DRY_RUN_CMD chmod 755 "$CADDY_DST"
      readlink -f "$CADDY_SRC" > "$CADDY_DST.src"
      $DRY_RUN_CMD /usr/bin/sudo setcap 'cap_net_bind_service=+ep' "$CADDY_DST"
      echo "caddy: applied cap_net_bind_service to $CADDY_DST"
    fi
  '';

  # CLI wrappers and git hooks for headless VMs
  home.file = {
    # Global git hooks (prevent commits/pushes to main)
    ".config/git-hooks/pre-commit" = {
      source = ./dotfiles/shell/git-hooks/pre-commit;
      executable = true;
    };
    ".config/git-hooks/pre-push" = {
      source = ./dotfiles/shell/git-hooks/pre-push;
      executable = true;
    };
    ".local/bin/vercel" = {
      source = ./dotfiles/shell/vercel-wrapper.sh;
      executable = true;
    };
    ".local/bin/pnpm" = {
      source = ./dotfiles/shell/pnpm-wrapper.sh;
      executable = true;
    };
  };
}
