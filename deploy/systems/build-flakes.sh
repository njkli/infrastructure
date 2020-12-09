#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git jq findutils bash nixFlakes curl

_msg() {
    curl -s \
         --form-string "token=${PUSHOVER_TOKEN}" \
         --form-string "user=${PUSHOVER_USER}" \
         --form-string "message=$1" \
         https://api.pushover.net/1/messages.json &> /dev/null
}

git clone https://${DEPLOYMENT_KEY}@github.com/njkli/systems.git
cd systems

for system in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r 'join("\n")')
do
    echo "****************************** Building: ${system} ******************************"
    nix-store --query --references $(nix build .#nixosConfigurations.${system}.config.system.build.toplevel --json | jq -r 'map(.drvPath) | join("\n")') \
        | xargs nix-store --realise \
        | xargs nix-store --query --requisites \
        | cachix push njk
    echo "****************************** Cleaning nix-store: ${system} ******************************"
    sudo nix-collect-garbage -d
    nix-collect-garbage -d
    echo "****************************** Done: ${system} ******************************"
    _msg "Done with ${system}"
done
