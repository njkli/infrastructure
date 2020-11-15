{ lib, ... }:
# # strict nix linter: pkgs, config,
let
  inherit (lib) replaceStrings head splitString nameValuePair;
  inherit (builtins) readFile fromJSON getEnv;

  dom = "ourubertest.io";
  domID_tf = replaceStrings [ "." ] [ "_" ] dom;

  terraform = (fromJSON (readFile ../terraform-providers.json)).terraform;

  provider.vultr.api_key = getEnv "VULTR_API_KEY";
  provider.vultr.rate_limit = 3000; # 3 sec.
  provider.vultr.retry_limit = 5;

in
{
  inherit terraform provider;

  resource.vultr_dns_domain."${domID_tf}" = {
    domain = dom;
    # server_ip = "127.0.0.1";
    dnssec = true;
  };

  data.vultr_dns_domain."${domID_tf}" = {
    domain = dom;
  };

  output.dnssec_info = { value = "\${ data.vultr_dns_domain.${domID_tf}.dnssec_info }"; };
}
