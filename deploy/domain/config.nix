{ lib, ... }:
# nix linter is strict: pkgs, config,
let
  inherit (lib) replaceStrings head splitString nameValuePair;
  inherit (builtins) readFile fromJSON getEnv;

  dom = getEnv "DEPLOY_DOMAIN";
  domID_tf = replaceStrings [ "." ] [ "_" ] dom;

  required_providers = (fromJSON (readFile ../terraform-providers.json)).terraform;
  terraform = {
    backend.artifactory.username = getEnv "ARTIFACTORY_UNAME";
    backend.artifactory.password = getEnv "ARTIFACTORY_PASSWD";
    backend.artifactory.url = getEnv "ARTIFACTORY_URL";
    backend.artifactory.repo = "tfstate";
    backend.artifactory.subpath = "domain-${dom}";
  } // required_providers;

  provider.vultr.api_key = getEnv "VULTR_API_KEY";
  provider.vultr.rate_limit = 3000; # 3 sec.
  provider.vultr.retry_limit = 5;

in
{
  inherit
    terraform
    provider;

  # TODO: make vultr_dns module
  # NOTE: https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source
  resource.vultr_dns_domain."${domID_tf}" = {
    domain = dom;
    server_ip = "127.0.0.1";
    provisioner = [
      {
        local-exec = [
          {
            command = "./dns_provisioner.sh create ${dom}"; # NOTE: runs on create only!
            interpreter = [ "bash" "-c" ];
          }
        ];
      }

      {
        local-exec = [
          {
            when = "destroy"; # NOTE: runs on destroy only!
            command = "./dns_provisioner.sh destroy ${dom}";
            interpreter = [ "bash" "-c" ];
          }
        ];
      }
    ];
  };
}
