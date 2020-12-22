{ lib, ... }:
let
  inherit (lib) nameValuePair mapAttrs' toLower last head splitString;
  inherit (builtins) readFile fromJSON getEnv;

  gh_repo = getEnv "GITHUB_REPOSITORY";
  repository = last (splitString "/" gh_repo);

  secrets = mapAttrs'
    (secret_name: plaintext_value: nameValuePair (toLower "gh_actions_secret_${secret_name}") {
      inherit repository secret_name plaintext_value;
    })
    (import /persist/etc/nixos/systems/secrets/credentials.nix).njk.credentials.env;
in
{
  imports = [ ../../nix/terranix ];
  tf.backends.s3.enable = true;
  tf.backends.s3.subpath = "deployments/github-secrets/terraform.tfstate";

  provider.github.token = getEnv "GITHUB_TOKEN";
  provider.github.owner = head (splitString "/" gh_repo);

  resource.github_actions_secret = secrets;
}
