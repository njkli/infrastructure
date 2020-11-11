{ project ? import ./nix { } }:

project.pkgs.mkShell {
  buildInputs = builtins.attrValues project.devTools;
  shellHook = ''
    ${project.ci.pre-commit-check.shellHook}
  '';
  lorriHook = ''
    [[ -r /persist/etc/nixos/systems/credentials.nix ]] && \
        eval "$(nix-instantiate --eval /persist/etc/nixos/systems/credentials.nix --attr njk.credentials.export_shell --json | jq -r)" || true
  '';
}
