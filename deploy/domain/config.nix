{ lib, ... }:

# strict nix linter: pkgs, config,
let
  inherit (lib) replaceStrings head splitString nameValuePair;
  inherit (builtins) getEnv;
  dom = getEnv "DEPLOY_DOMAIN";
in
{
  imports = [ ../../nix/terranix ];

  tf.backends.s3.enable = true;
  tf.backends.s3.subpath = "deployments/domain-${dom}";

  vultr.enable = true;
  vultr.api_key = getEnv "VULTR_API_KEY";

  vultr.dns.domains."${dom}" = [
    # Github pages
    { name = dom; data = "185.199.108.153"; type = "A"; }
    { name = dom; data = "185.199.109.153"; type = "A"; }
    { name = dom; data = "185.199.110.153"; type = "A"; }
    { name = dom; data = "185.199.111.153"; type = "A"; }
    { name = "www"; data = "njkli.github.io"; type = "CNAME"; }
  ];

  # output.domain_id = { value = "\${ vultr_dns_domain.${dom}.id }"; };
}
