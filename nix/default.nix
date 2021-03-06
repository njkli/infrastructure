{ sources ? import ./sources.nix }:
let
  pkgs = import sources.nixpkgs { };
  inherit (pkgs) callPackage writeShellScriptBin fetchFromGitHub;
  inherit (pkgs.lib) getAttrs mapAttrs replaceStrings fileContents;
  inherit (builtins) toJSON fromJSON;

  gitignoreSource = (import sources."gitignore.nix" { inherit (pkgs) lib; }).gitignoreSource;
  pre-commit-hooks = (import sources."pre-commit-hooks.nix");
  src = gitignoreSource ./..;

  terranix_release = callPackage sources.terranix { };
  tf = import ./terraform { inherit pkgs; };
  tf_scripts_path = "${pkgs.path}/pkgs/applications/networking/cluster/terraform-providers/";

  scripts = {
    update-provider = writeShellScriptBin "update-provider" (fileContents (tf_scripts_path + "update-provider"));
    update-all-providers = writeShellScriptBin "update-all-providers" (
      replaceStrings
        [ "./update-provider" ]
        [ "update-provider" ]
        (fileContents (tf_scripts_path + "update-all-providers"))
    );

    tf-update-providers = writeShellScriptBin "tf-update-providers" ''
      update-all-providers
    '';

    localDevCredentials = writeShellScriptBin "localDevCredentials" ''
      [[ -r /persist/etc/nixos/systems/secrets/credentials.nix ]] && \
        eval "$(nix-instantiate --eval /persist/etc/nixos/systems/secrets/credentials.nix --attr njk.credentials.export_shell --json | jq -r)" || true
    '';

    # https://goobar.io/manually-trigger-a-github-actions-workflow/
    repo_trigger_build = writeShellScriptBin "repo_trigger_build" ''
      gh api repos/:owner/:repo/dispatches -X POST --raw-field event_type=manual_trigger
    '';

    # TODO: integrate passwd_tomb
    # PASSWORD_STORE_TOMB_FILE=<tomb_path> PASSWORD_STORE_TOMB_KEY=<key_path> PASSWORD_STORE_DIR=<dir_path> pass open
    # PASSWORD_STORE_TOMB_FILE=<tomb_path> PASSWORD_STORE_TOMB_KEY=<key_path> PASSWORD_STORE_DIR=<dir_path> pass close
    # PASSWORD_STORE_DIR=$PWD/secrets

    what_to_deploy = writeShellScriptBin "what_to_deploy" ''
      git log --name-only -n 1 --format=""
    '';

    build-ipxe-release = writeShellScriptBin "build-ipxe-release" ''
      BINCACHEDIR="''${PWD}/bincache"
      mkdir -p "''${BINCACHEDIR}"
      flake_url="git+https://''${DEPLOYMENT_KEY}@github.com/njkli/systems"

      src_dir=$(nix build ''${flake_url}#nixosConfigurations.installer-public-img.config.system.build.netbootRelease --impure --json | jq -r '.[] | .outputs.out')
      cp $src_dir/* ''${BINCACHEDIR}
    '';

    # FIXME: Should really switch to github caching of /nix dir or use cachix properly here
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

    github-actions-secrets-yaml = writeShellScriptBin "github-actions-secrets-yaml" ''
      nix-instantiate --eval  /persist/etc/nixos/systems/secrets/credentials.nix --attr njk.credentials.export_actions --json | remarshal --if json --of yaml
    '';

    tf-required_providers = writeShellScriptBin "tf-required_providers" ''
      cat > ../terraform-providers.json<<EOS
      ${toJSON tf.terraform_plugins_json}
      EOS
    '';

    tf-deploy = writeShellScriptBin "tf-deploy" ''
      set -e
      set -o pipefail
      tf-required_providers
      terranix --with-nulls | jq '.' > config.tf.json
      terraform init -upgrade &> /dev/null
      terraform apply -input=false -auto-approve
    '';

    tf-destroy = writeShellScriptBin "tf-destroy" ''
      terraform init &> /dev/null
      terraform destroy -input=false -auto-approve
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
      jq moreutils coreutils
      httpie
      vultr-cli
      scaleway-cli
      doctl
      github-release
      github-cli
      dnsutils
      remarshal
      k9s
      kubectl
      fluxctl
      kubernetes-helm;
    terraform = tf.terraform_with_plugins;
    # ruby = pkgs.ruby.withPackages (p: [ p.rbnacl ]);
  } // scripts;

  # to be built by github actions
  ci = {
    pre-commit-check = pre-commit-hooks.run {
      inherit src;
      hooks = {
        shellcheck.enable = true;
        nixpkgs-fmt.enable = true;
        nix-linter.enable = false; # FIXME: re-enable nix-linter
      };

      # generated files
      excludes = [
        "^nix/sources\.nix$"
        "^\.pre\-commit\-config\.yaml$"
        "^result$"
      ];
    };
  };
}
