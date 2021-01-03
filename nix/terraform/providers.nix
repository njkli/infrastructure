{ lib
, buildGoModule
, buildGoPackage
, fetchFromGitHub
, callPackage
, runtimeShell
}:
let
  list = lib.importJSON ./providers.json;

  buildWithGoModule = data:
    buildGoModule {
      pname = data.repo;
      version = data.version;
      subPackages = [ "." ];
      src = fetchFromGitHub {
        inherit (data) owner repo rev sha256;
      };
      vendorSha256 = data.vendorSha256 or null;
      postBuild = "mv $NIX_BUILD_TOP/go/bin/${data.repo}{,_v${data.version}}";
      passthru = data;
    };

  buildWithGoPackage = data:
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

  automated-providers = lib.mapAttrs
    (_: attrs:
      (if (lib.hasAttr "vendorSha256" attrs) then buildWithGoModule else buildWithGoPackage)
        attrs)
    list;
in
automated-providers
