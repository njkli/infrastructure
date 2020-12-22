{ config, lib, ... }:
let
  inherit (lib) mkMerge mkIf types mkOption mkEnableOption mkDefault;
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

    # https://blogs.oracle.com/linux/using-rclone-to-copy-data-in-and-out-of-oracle-cloud-object-storage
    # https://d-heinrich.medium.com/move-your-terraform-backend-to-any-custom-s3-84f376dcafe6

    s3 = {
      enable = mkEnableOption "s3 backend";
      endpoint = mkOption {
        type = str;
        # mynamespace.compat.objectstorage.us-phoenix-1.oraclecloud.com
        default = "axdblkstnkzq.compat.objectstorage.eu-amsterdam-1.oraclecloud.com";
        description = ''
          Endpoint mynamespace
        '';
      };

      region = mkOption {
        type = str;
        default = "us-east-1"; # https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm [Important part!]
        description = ''
          S3 Region
        '';
      };

      bucket = mkOption {
        type = str;
        default = "tfstate";
        description = ''
          Backend S3 bucket
        '';
      };

      subpath = mkOption {
        type = str;
        default = "tfstate";
        description = ''
          (Required) Path to the state file inside the S3 Bucket.
        '';
      };

      access_key = mkOption {
        type = str;
        default = "tfstate";
        description = ''
          AWS_ACCESS_KEY
        '';
      };

      secret_key = mkOption {
        type = str;
        default = "tfstate";
        description = ''
          AWS_SECRET_KEY
        '';
      };

    };
  };

  config = mkMerge [
    (mkIf cfg.s3.enable {
      terraform.backend.s3.bucket = cfg.s3.bucket;
      terraform.backend.s3.region = cfg.s3.region;
      terraform.backend.s3.secret_key = mkDefault (getEnv "ORACLE_SECRET_KEY");
      terraform.backend.s3.access_key = mkDefault (getEnv "ORACLE_ACCESS_KEY");
      terraform.backend.s3.key = cfg.s3.subpath;
      terraform.backend.s3.endpoint = cfg.s3.endpoint;
      terraform.backend.s3.force_path_style = true; # NOTE: needed for Oracle - https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm
      terraform.backend.s3.skip_region_validation = true;
      terraform.backend.s3.skip_credentials_validation = true;
    })

    (mkIf cfg.artifactory.enable
      {
        terraform.backend.artifactory.username = mkDefault (getEnv "ARTIFACTORY_UNAME");
        terraform.backend.artifactory.password = mkDefault (getEnv "ARTIFACTORY_PASSWD");
        terraform.backend.artifactory.url = mkDefault (getEnv "ARTIFACTORY_URL");
        terraform.backend.artifactory.repo = cfg.artifactory.repo;
        terraform.backend.artifactory.subpath = cfg.artifactory.subpath;
      })
  ];
}
