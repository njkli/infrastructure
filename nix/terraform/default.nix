# NOTE: https://github.com/tweag/terraform-nixos
# NOTE: https://github.com/andrewchambers/terraform-provider-nix
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

/*
  "scaleway": {
    "owner": "scaleway",
    "provider-source-address": "registry.terraform.io/scaleway/scaleway",
    "repo": "terraform-provider-scaleway",
    "rev": "v2.0.0-rc1",
    "sha256": "15llwblm8kxzpx4c0lzqpf6za0iyic665245glk4hsmas763f3fq",
    "vendorSha256": null,
    "version": "2.0.0-rc1"
  },

*/
