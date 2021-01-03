{ lib, ... }:
let
  inherit (lib) mkMerge importJSON;
  inherit (builtins) fromJSON readFile;
  terraform = (importJSON ../../../deploy/terraform-providers.json).terraform;
in
{
  # TODO: lib functions
  # options.tf.common = {
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
