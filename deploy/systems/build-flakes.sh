#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git jq findutils bash
mkdir -p $HOME/.ssh
echo $DEPLOYMENT_KEY > $HOME/.ssh/id_rsa
echo 'StrictHostKeyChecking no' > $HOME/.ssh/config
chmod 0600 $HOME/.ssh/id_rsa

git clone git@github.com:njkli/systems.git
cd systems

for system in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r 'join("\n")')
do
    nix-store --query --references \
              $(nix build .#nixosConfigurations.${system}.config.system.build.toplevel --json | jq -r 'map(.drvPath) | join("\n")') \
        | xargs nix-store --realise \
        | xargs nix-store --query --requisites \
        | cachix push njk
done
