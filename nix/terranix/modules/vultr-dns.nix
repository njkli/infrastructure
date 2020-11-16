{ config, lib, pkgs, ... }:
let
  cfg = config.vultr;
  inherit (lib)
    mkMerge mkIf types
    mkOption mkEnableOption
    replaceStrings
    mapAttrs' nameValuePair concatMapStringsSep attrValues attrNames flatten listToAttrs;
  inherit (pkgs) writeShellScript;
  inherit (builtins) readFile hashString toString;

  provisioner_script = writeShellScript "vultr_dns_provisioner" (readFile ../scripts/vultr_dns_provisioner.sh);
  domID_tf = replaceStrings [ "." ] [ "_" ];
  recID_tf = _: domain: "_" + hashString "sha256" (concatMapStringsSep "|" (toString) (attrValues (_ // { inherit domain; })));

  provisioner = dom: [
    {
      local-exec = [
        {
          command = "${provisioner_script} create ${dom}"; # NOTE: runs on create only!
          interpreter = [ "bash" "-c" ];
        }
      ];
    }

    {
      local-exec = [
        {
          when = "destroy"; # NOTE: runs on destroy only!
          command = "${provisioner_script} destroy ${dom}";
          interpreter = [ "bash" "-c" ];
        }
      ];
    }
  ];

  record_opts = with types; { ... }: {
    options = {
      ttl = mkOption {
        description = "Record ttl";
        default = 120;
        type = int;
      };
      type = mkOption {
        description = "Record type";
        # NOTE: those are the only record types supported by vultr :(
        type = enum [ "A" "AAAA" "CNAME" "NS" "MX" "SRV" "TXT" "CAA" "SSHFP" ];
      };
      name = mkOption {
        default = "";
        description = "Record name";
        type = str;
      };
      data = mkOption {
        description = "Record data";
        type = str;
      };
    };
  };

in
{
  options.vultr = with types; {
    enable = mkEnableOption "vultr dns support";
    api_key = mkOption {
      description = "api key";
      type = str;
    };

    dns = {
      domains = mkOption {
        description = "Configured domains";
        type = attrsOf (listOf (submodule [ record_opts ]));
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      provider.vultr.api_key = cfg.api_key;
      provider.vultr.rate_limit = 3000; # 3 sec.
      provider.vultr.retry_limit = 5;

      resource.vultr_dns_domain = mapAttrs'
        (domain: _: nameValuePair (domID_tf domain) {
          # NOTE: server_ip = "169.254.1.1"; forces replacement!
          # https://github.com/vultr/terraform-provider-vultr/blob/df735bc6d530a69eccabc820dd759bfeeb840da0/vultr/resource_vultr_dns_domain.go#L60
          inherit domain;
          server_ip = "127.0.0.1";
          provisioner = provisioner domain;
        })
        cfg.dns.domains;
      resource.vultr_dns_record =
        let
          # FIXME: refactor into separate functions!
          doms = map (domain: (map (r: nameValuePair (recID_tf r domain) (r // { inherit domain; depends_on = [ "vultr_dns_domain.${domID_tf domain}" ]; })) cfg.dns.domains."${domain}")) (attrNames cfg.dns.domains);
        in
        listToAttrs (flatten doms);
    })
  ];
}
/*

Possible η-reduction of argument `d` at nix/terranix/modules/vultr-dns.nix:13:14-49
Possible η-reduction of argument `v` at nix/terranix/modules/vultr-dns.nix:14:77-90

*/
