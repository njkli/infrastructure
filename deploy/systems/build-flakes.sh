#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git jq findutils bash nixFlakes curl

_msg() {
    curl -s \
         --form-string "token=${PUSHOVER_TOKEN}" \
         --form-string "user=${PUSHOVER_USER}" \
         --form-string "message=$1" \
         https://api.pushover.net/1/messages.json &> /dev/null
}

flake_url="git+https://${DEPLOYMENT_KEY}@github.com/njkli/systems"

for system in $(nix eval ${flake_url}#nixosConfigurations --apply builtins.attrNames --json | jq -r 'join("\n")')
do
    echo "****************************** Building: ${system} ******************************"
    nix-store --query --references $(nix build ${flake_url}#nixosConfigurations.${system}.config.system.build.toplevel --json | jq -r 'map(.drvPath) | join("\n")') \
        | xargs nix-store --realise \
        | xargs nix-store --query --requisites \
        | cachix push njk && _msg "Passed: ${system}" || _msg "Failed: ${system}"
    echo "****************************** Cleaning nix-store: ${system} ******************************"
    # sudo nix-collect-garbage -d
    nix-collect-garbage -d
    echo "****************************** Done: ${system} ******************************"
done

# except for marvin
