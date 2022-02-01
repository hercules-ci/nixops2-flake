{
  inputs = {
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
        nativeBuildInputs = [
          pkgs.hci
          pkgs.nixopsUnstable
        ];
        shellHook = ''
          echo Welcome to the project shell!
          echo
          echo You can run effects locally with
          echo "  hci secret --help to manage your local copies of secrets"
          echo "  hci effect run --as-branch main effects.staging-hello.run"
          echo
          echo "NOTE: If you're doing this in a fresh repo or fresh branch,"
          echo "      make sure to create a commit and set the branch upstream."
          echo "      This provides necessary context for the hci command."
          echo "      You can do this by pushing to your remote with the -u flag."
          echo
          echo "Now use tab completion to your heart's desire. Happy hacking!"
        '';
      }
    );

    nixopsConfigurations.default =
      let
        accessKeyId = "nixops-example";
        region = "us-east-1";
        tags = {};
        name = "default";
      in {
        inherit nixpkgs;
        network.storage.hercules-ci = {
          stateName = "${name}.nixops";
        };
        network.lock.hercules-ci = {
          stateName = "${name}.nixops";
        };
        network.description = name; # usage is identifier-like
        defaults = { config, lib, pkgs, resources, ... }: {
          deployment.targetEnv = "ec2";
          deployment.ec2 = {
            inherit region tags accessKeyId;
            keyPair = resources.ec2KeyPairs.keypair;
          };
          documentation.enable = false;
        };
        resources = {

          ec2KeyPairs.keypair = {
            name = "nixops-${name}";
            inherit region accessKeyId;
          };

          ec2SecurityGroups.ssh = { resources, ... }: {
            name = "${name}-ssh";
            description = "Allow SSH access from anywhere";
            rules = [
              { fromPort = 22; toPort = 22; sourceIp = "0.0.0.0/0"; }
            ];
            inherit region tags accessKeyId;
          };

          ec2SecurityGroups.web = { resources, ... }: {
            name = "${name}-web";
            description = "Allow HTTP/HTTPS access from anywhere";
            rules = [
              { fromPort = 80; toPort = 80; sourceIp = "0.0.0.0/0"; }
              { fromPort = 443; toPort = 443; sourceIp = "0.0.0.0/0"; }
            ];
            inherit region tags accessKeyId;
          };

        };

        webserver = { lib, pkgs, resources, ... }: {
          deployment.ec2.instanceType = "t3.small";
          deployment.ec2.securityGroups = [
            resources.ec2SecurityGroups.ssh.name
            resources.ec2SecurityGroups.web.name
          ];
          networking.firewall.allowedTCPPorts = [80 443];
          services.nginx.enable = true;
          services.nginx.virtualHosts.localhost.root = "${pkgs.nix.doc}/share/doc/nix/manual";
        };
      };

    effects = { src }:
    let
      pkgs = nixpkgs.legacyPackages.${cdSystem};
      effects = hercules-ci-effects.lib.withPkgs pkgs;
    in {

      # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/runif/
      staging-hello = effects.runIf (src.ref == "refs/heads/main") (

        # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/runnixops2/
        effects.runNixOps2 {
          flake = self;

          userSetupScript = ''
            mkdir -p ~/.config/nix
            echo 'experimental-features = nix-command flakes' >>~/.config/nix/nix.conf

            # See https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/writeawssecret/
            writeAWSSecret aws nixops-example

            # if your hosts' keys aren't managed by nixops, you can provide your own key
            # https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/writesshkey/
            # writeSSHKey ssh

            # You can add any other initialization here
            # See readSecretString and other functions at
            # https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/readsecretstring/
          '';

          # https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/mkeffect/#param-secretsMap
          #
          # To run locally, copy your ssh key with
          #   hci secret init-local
          #   hci secret add ssh --string-file privateKey ~/.ssh/id_rsa --string-file publicKey ~/.ssh/id_rsa.pub
          # secretsMap.ssh = "ssh";
          secretsMap.aws = "nixops-example-aws";
        });
    };
  };
}
