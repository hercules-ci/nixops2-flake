{
  inputs = {
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
  };

  outputs = { self, flake-compat-ci, nixpkgs, hercules-ci-effects, ... }:
  let
    devSystems = [ "x86_64-linux" "aarch64-darwin" ];
    ciSystems = devSystems;
    cdSystem = "x86_64-linux";
  in
  {
    ciNix = args@{ src }: flake-compat-ci.lib.recurseIntoFlakeWith {
      flake = self;
      systems = ciSystems;
      effectsArgs = args;
    };

    devShell = nixpkgs.lib.genAttrs devSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in pkgs.mkShell {
        nativeBuildInputs = [ pkgs.hci ];
        shellHook = ''
          echo Welcome to the project shell!
          echo
          echo You can run effects locally with
          echo "  hci secret --help to manage your local copies of secrets"
          echo "  hci effect run --as-branch main effects.staging-hello.run"
          echo
          echo NOTE: If you're doing this in a fresh repo or fresh branch,
          echo       make sure to create a commit and set the branch upstream.
          echo       This provides necessary context for the hci command.
          echo       You can do this by pushing to your remote with the -u flag.
          echo
          echo "Now use tab completion to your heart's desire. Happy hacking!"
        '';
      }
    );

    effects = { src }:
    let
      pkgs = nixpkgs.legacyPackages.${cdSystem};
      effects = hercules-ci-effects.lib.withPkgs pkgs;
    in {

      # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/runif/
      staging-hello = effects.runIf (src.ref == "refs/heads/main") (

        # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/mkeffect/
        effects.mkEffect {
          # if your effect needs to read the source
          # src = self;
          inputs = [ pkgs.openssh ];
          effectScript = ''
            # https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/writesshkey/
            writeSSHKey ssh
            ${effects.ssh { # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/ssh/
                destination = "staging.example.com";
              } ''
                ${nixpkgs.legacyPackages.x86_64-linux.hello}/bin/hello
              ''}
          '';

          # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/mkeffect/#param-secretsMap
          #
          # To run locally, copy your ssh key with
          #   hci secret init-local
          #   hci secret add ssh --string-file privateKey ~/.ssh/id_rsa --string-file publicKey ~/.ssh/id_rsa.pub
          secretsMap.ssh = "ssh";
        });
    };
  };
}
