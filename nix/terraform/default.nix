{ pkgs, ... }:
let
  inherit (pkgs) buildGoPackage fetchFromGitHub;
  inherit (pkgs.lib) importJSON mapAttrs getAttrs attrValues length optional;

  # "vultr"
  providers_nixpkgs = [ "null" "helm" "digitalocean" "kubernetes" "github" "vultr" "oci" ];
  providers_custom = importJSON ./providers.json;

  toDrv = name: data:
    buildGoPackage {
      pname = data.repo;
      version = data.version;
      goPackagePath = "github.com/${data.owner}/${data.repo}";
      subPackages = [ "." ];
      src = fetchFromGitHub {
        inherit (data) owner repo rev sha256;
      };
      postBuild = "mv $NIX_BUILD_TOP/go/bin/${data.repo}{,_v${data.version}}";
      passthru = data;
    };

  patchGoModVendor = drv:
    drv.overrideAttrs (attrs: {
      buildFlags = "-mod=vendor";
      configurePhase = ''
        export GOPATH=$NIX_BUILD_TOP/go:$GOPATH
        export GOCACHE=$TMPDIR/go-cache
        export GO111MODULE=on
      '';
      buildPhase = ''
        go install -mod=vendor -v -p 16 .
        runHook postBuild
      '';
      doCheck = false;
    });

  automated-providers = mapAttrs (toDrv) providers_custom;

  special-providers = {
    # Override providers that use Go modules + vendor/ folder
    # artifactory = patchGoModVendor automated-providers.artifactory;
    vultr = patchGoModVendor automated-providers.vultr;
    /*
        "artifactory": {
            "owner": "jfrog",
            "repo": "terraform-provider-artifactory",
            "rev": "v2.2.4",
            "sha256": "1m8cr3ck01y7p269bd9n1m1jmfnkiyig5c1aal8xdb1fasfqngrv",
            "version": "2.2.4"
        },

    */
    # providers that were moved to the `hashicorp` organization,
    # but haven't updated their references yet:

    # artifactory = automated-providers.artifactory.overrideAttrs (attrs: {
    #   prePatch = attrs.prePatch or "" + ''
    #     substituteInPlace go.mod --replace terraform-providers/terraform-provider-artifactory jfrog/terraform-provider-artifactory
    #     substituteInPlace main.go --replace terraform-providers/terraform-provider-artifactory jfrog/terraform-provider-artifactory
    #   '';
    # });
  };


  all-providers = automated-providers; # // special-providers;  ++ (attrValues all-providers)

  terraform_with_plugins = pkgs.terraform_0_13.withPlugins (p: (map (x: p."${x}") providers_nixpkgs));
  terraform_plugins_json =
    let
      providers = (getAttrs providers_nixpkgs pkgs.terraform-providers) // all-providers;
      required_providers = mapAttrs
        (name: plugin: {
          version = plugin.version;
          source = plugin.provider-source-address or "nixpkgs/${name}";
        })
        providers;
    in
    { terraform = { inherit required_providers; }; };

in
{ inherit terraform_with_plugins terraform_plugins_json; }
