{ lib, ... }:
# strict nix linter: pkgs, config,
let
  inherit (lib) replaceStrings head splitString nameValuePair;
  inherit (builtins) getEnv;

  dom = getEnv "DEPLOY_DOMAIN";
in
{
  imports = [ ../../nix/terranix ];

  tf.backends.artifactory.enable = true;
  tf.backends.artifactory.subpath = "domain-${dom}";

  vultr.enable = true;
  vultr.api_key = getEnv "VULTR_API_KEY";

  vultr.dns.domains."${dom}" = [
    # Github pages
    { name = ""; data = "185.199.108.153"; type = "A"; }
    { name = ""; data = "185.199.109.153"; type = "A"; }
    { name = ""; data = "185.199.110.153"; type = "A"; }
    { name = ""; data = "185.199.111.153"; type = "A"; }
    { name = "www"; data = "njkli.github.io"; type = "CNAME"; }
  ];

  # output.domain_id = { value = "\${ vultr_dns_domain.prv_rocks.id }"; };
}
