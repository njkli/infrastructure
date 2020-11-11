{ lib, ... }:
# pkgs, config,
let
  inherit (lib) replaceStrings head splitString nameValuePair;
  inherit (builtins) readFile fromJSON getEnv;

  dom = getEnv "DEPLOY_DOMAIN";
  domID_tf = replaceStrings [ "." ] [ "_" ] dom;

  required_providers = fromJSON (readFile ../terraform-providers.json);
  terraform = {
    backend.artifactory.username = getEnv "ARTIFACTORY_UNAME";
    backend.artifactory.password = getEnv "ARTIFACTORY_PASSWD";
    backend.artifactory.url = getEnv "ARTIFACTORY_URL";
    backend.artifactory.repo = "tfstate";
    backend.artifactory.subpath = "domain-${dom}";
  } // required_providers.terraform;

  provider.vultr.api_key = getEnv "VULTR_API_KEY";
  provider.vultr.rate_limit = 3000; # NOTE: ms between requests!
  provider.vultr.retry_limit = 5;

in
{
  inherit
    terraform
    provider;

  # TODO: make vultr_dns module
  resource.vultr_dns_domain."${domID_tf}" = {
    domain = dom;
    server_ip = "127.0.0.1";
    provisioner = [
      {
        local-exec = [
          {
            command = "echo create"; # NOTE: runs on create only!
          }
        ];
      }

      {
        local-exec = [
          {
            when = "destroy"; # NOTE: runs on destroy only!
            command = "echo destroy";
          }
        ];
      }
    ];
  };
}
