{ lib, ... }:
let
  inherit (lib) nameValuePair mapAttrs' toLower;
  inherit (builtins) readFile fromJSON getEnv;

  required_providers = (fromJSON (readFile ../terraform-providers.json)).terraform;
  terraform = {
    backend.artifactory.username = getEnv "ARTIFACTORY_UNAME";
    backend.artifactory.password = getEnv "ARTIFACTORY_PASSWD";
    backend.artifactory.url = getEnv "ARTIFACTORY_URL";
    backend.artifactory.repo = "tfstate";
    backend.artifactory.subpath = "secrets-github";
  } // required_providers;

  provider.github.token = getEnv "GITHUB_TOKEN";
  provider.github.owner = "njkli";

  secrets = mapAttrs'
    (secret_name: plaintext_value: nameValuePair (toLower "gh_actions_secret_${secret_name}") {
      repository = "infrastructure";
      inherit secret_name plaintext_value;
      # secret_name = secret_name;
      # plaintext_value = s_value;
    })
    (import /persist/etc/nixos/systems/credentials.nix).njk.credentials.env;
in
{
  inherit
    terraform
    provider;
  resource.github_actions_secret = secrets;
}
