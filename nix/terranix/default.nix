{ lib, ... }:
let
  inherit (lib) attrNames filterAttrs hasSuffix;
  inherit (builtins) readDir;
in
{
  imports = map (x: ./modules/. + "/${x}") (attrNames (filterAttrs (n: _: hasSuffix ".nix" n) (readDir ./modules)));
}

# NOTE: https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source
