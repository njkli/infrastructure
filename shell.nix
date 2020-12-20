{ project ? import ./nix { } }:
#
project.pkgs.mkShell {
  buildInputs = builtins.attrValues project.devTools;
  shellHook = ''
    ${project.ci.pre-commit-check.shellHook}
  '';

  lorriHook = let fn = "/persist/etc/nixos/systems/secrets/credentials.nix"; in
    ''
      [[ -r ${fn} ]] && \
          eval "$(nix eval --impure --expr '(import ${fn}).njk.credentials.export_shell' --json | jq -r)" || true
    '';
}
