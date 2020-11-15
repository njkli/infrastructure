{ lib, ... }:
let
  inherit (lib) mkMerge;
  inherit (builtins) fromJSON readFile;
  terraform = (fromJSON (readFile ../../../deploy/terraform-providers.json)).terraform;
in
{
  # TODO: lib functions
  # options.tf-common = {
  #   lib = mkOption {
  #     type = attrs;
  #     default = import ../../lib;
  #     description = "lib conveniences";
  #   };
  # };

  config = mkMerge [
    { inherit terraform; }
  ];
}
