{ pkgs, ... }:
let
  inherit (pkgs) buildGoPackage fetchFromGitHub callPackage;
  inherit (pkgs.lib)
    filterAttrs recurseIntoAttrs mapAttrs getAttrs attrValues
    importJSON elem;

  providers = [ "null" "helm" "digitalocean" "kubernetes" "github" "vultr" "oci" ];
  providers_custom = recurseIntoAttrs (callPackage ./providers.nix { });
  attrFilter = filterAttrs (k: _: elem k providers);
  providers_input = attrFilter pkgs.terraform-providers // attrFilter providers_custom; # overwrite with custom
  terraform_with_plugins = pkgs.terraform_0_14.withPlugins (p: attrValues providers_input);

  terraform_plugins_json.terraform.required_providers = mapAttrs
    (name: plugin: {
      version = plugin.version;
      source = plugin.provider-source-address or "nixpkgs/${name}";
    })
    providers_input;
in
{ inherit terraform_with_plugins terraform_plugins_json; }
