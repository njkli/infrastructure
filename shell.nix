{ project ? import ./nix { } }:

project.pkgs.mkShell {
  buildInputs = builtins.attrValues project.devTools;
  shellHook = ''
    ${project.ci.pre-commit-check.shellHook}
  '';

  lorriHook = ''
    [[ -r /persist/etc/nixos/systems/credentials.nix ]] && \
        eval "$(nix eval --impure --expr '(import /mnt/config/secrets/credentials.nix).njk.credentials.export_shell' --json | jq -r)" || true
  '';
}
