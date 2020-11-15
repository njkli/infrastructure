{ lib, ... }:
let
  inherit (lib) attrNames filterAttrs hasSuffix;
  inherit (builtins) readDir toPath;
in
{
  imports = map (x: ./modules/. + "/${x}") (attrNames (filterAttrs (n: _: hasSuffix ".nix" n) (readDir ./modules)));
}
