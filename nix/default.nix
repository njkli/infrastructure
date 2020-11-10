{ sources ? import ./sources.nix }:
let
  pkgs = import sources.nixpkgs { };
  inherit (pkgs) callPackage writeShellScriptBin;
  inherit (pkgs.lib) getAttrs mapAttrs;
  inherit (builtins) toJSON;

  gitignoreSource = (import sources."gitignore.nix" { inherit (pkgs) lib; }).gitignoreSource;
  pre-commit-hooks = (import sources."pre-commit-hooks.nix");
  src = gitignoreSource ./..;

  terranix_release = callPackage sources.terranix { };

  # NOTE: Set those before using, TF 0.13
  terraform_providers = [ "null" "helm" "vultr" "digitalocean" "kubernetes" ];
  terraform_plugins =
    let
      providers = (getAttrs terraform_providers pkgs.terraform-providers);
      required_providers = mapAttrs
        (name: plugin: {
          version = plugin.version;
          source = plugin.provider-source-address or "nixpkgs/${name}";
        })
        providers;
    in
    { terraform = { inherit required_providers; }; };

  scripts = {
    binary-cache-build = writeShellScriptBin "binary-cache-build" ''
      BINCACHEDIR="''${PWD}/bincache"
      mkdir -p "''${BINCACHEDIR}"

      echo $CACHE_SIGNING_KEY > CACHE_SIGNING_KEY
      chmod 0500 CACHE_SIGNING_KEY

      for store_path in $(nix-store --query --references $(nix-instantiate shell.nix) | xargs nix-store --realise | xargs nix-store --query --requisites)
      do
        # echo $store_path

        nix sign-paths --key-file CACHE_SIGNING_KEY "''${store_path}"
        nix copy --to "file:///''${BINCACHEDIR}" "''${store_path}"
      done

      rm -rf CACHE_SIGNING_KEY
    '';

    tf-required_providers = writeShellScriptBin "tf-required_providers" ''
      # FIXME: remove the mkdir, after deploy folder is added
      mkdir -p ./deploy
      cat > ./deploy/terraform-providers.json<<EOS
      ${toJSON terraform_plugins}
      EOS
    '';

    deploy = writeShellScriptBin "tf-deploy" ''
      set -e
      set -o pipefail
      tf-required_providers
      terranix | jq '.' > config.tf.json
      terraform init &> /dev/null
      terraform apply -input=false -auto-approve
    '';

    destroy = writeShellScriptBin "tf-destroy" ''
      terraform destroy
    '';
  };

in
{
  inherit pkgs src;
  # provided by shell.nix
  devTools = {
    inherit terranix_release;
    inherit (pre-commit-hooks) pre-commit;
    inherit (pkgs)
      niv
      jq
      httpie
      vultr-cli
      scaleway-cli
      doctl
      github-release
      github-cli
      k9s
      kubectl
      fluxctl
      kubernetes-helm;
    terraform = pkgs.terraform_0_13.withPlugins (p: (map (x: p."${x}") terraform_providers));
  } // scripts;

  # to be built by github actions
  ci = {
    pre-commit-check = pre-commit-hooks.run {
      inherit src;
      hooks = {
        shellcheck.enable = true;
        nixpkgs-fmt.enable = true;
        nix-linter.enable = true;
      };
      # generated files
      excludes = [ "^nix/sources\.nix$" "^\.pre\-commit\-config\.yaml$" "^result$" ];
    };
  };
}
