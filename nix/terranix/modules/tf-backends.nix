{ config, lib, ... }:
let
  inherit (lib) mkMerge mkIf types mkOption mkEnableOption;
  inherit (builtins) getEnv;

  cfg = config.tf.backends;
in
{
  options.tf.backends = with types; {
    artifactory = {
      enable = mkEnableOption "jfrog Artifactory backend";
      subpath = mkOption {
        type = str;
        description = ''
          subpath
        '';
      };
      repo = mkOption {
        type = str;
        default = "tfstate";
        description = ''
          repo
        '';
      };
    };

  };

  config = mkMerge [
    (mkIf cfg.artifactory.enable
      {
        terraform.backend.artifactory.username = getEnv "ARTIFACTORY_UNAME";
        terraform.backend.artifactory.password = getEnv "ARTIFACTORY_PASSWD";
        terraform.backend.artifactory.url = getEnv "ARTIFACTORY_URL";
        terraform.backend.artifactory.repo = cfg.artifactory.repo;
        terraform.backend.artifactory.subpath = cfg.artifactory.subpath;
      })
  ];
}
