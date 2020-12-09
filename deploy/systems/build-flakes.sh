#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git jq findutils bash nixFlakes

git clone https://${DEPLOYMENT_KEY}@github.com/njkli/systems.git
cd systems

echo '******************************'
nix build --help
# nix --version
echo '******************************'

for system in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r 'join("\n")')
do
    echo '******************************'
    echo ${system}
    echo '******************************'
    nix-store --query --references $(nix build .#nixosConfigurations.${system}.config.system.build.toplevel --json | jq -r 'map(.drvPath) | join("\n")') \
        | xargs nix-store --realise \
        | xargs nix-store --query --requisites \
        | cachix push njk
    echo '******************************'
done

# mkdir -p $HOME/.ssh && \
#     echo $DEPLOYMENT_KEY > $HOME/.ssh/id_rsa && \
#     echo 'StrictHostKeyChecking no' > $HOME/.ssh/config && \
#     chmod 0600 $HOME/.ssh/id_rsa && \
#     cat $HOME/.ssh/id_rsa && \
