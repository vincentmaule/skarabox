{
  description = "Flake for skarabox.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    skarabox.url = "github:ibizaman/skarabox";
    skarabox.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, skarabox, sops-nix, deploy-rs }: flake-parts.lib.mkFlake { inherit inputs; } (let
      readFile = path: nixpkgs.lib.trim (builtins.readFile path);
  in {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    perSystem = { self', inputs', pkgs, system, ... }: {
      packages = {
        inherit (inputs'.nixpkgs.legacyPackages) age mkpasswd usbimager util-linux ssh-to-age openssl yq;

        beacon = skarabox.lib.beacon system {
          skarabox.sshPublicKey = ./ssh_skarabox.pub;
        };

        beacon-vm = pkgs.writeShellScriptBin "beacon-vm" (let
          vm = skarabox.lib.beacon-vm system {
            skarabox.sshPublicKey = ./ssh_skarabox.pub;
          };
        in ''
          ssh_port=${readFile ./ssh_port}
          ssh_boot_port=${readFile ./ssh_boot_port}
          ${vm}/bin/beacon-vm \
            ''${ssh_port} \
            ''${ssh_boot_port} \
            $@
        '');

        # nix run .#gen-knownhosts-file
        gen-knownhosts-file = pkgs.writeShellScriptBin "gen-knownhosts-file" ''
          ip=${readFile ./ip}
          ssh_port=${readFile ./ssh_port}
          ssh_boot_port=${readFile ./ssh_boot_port}

          ${inputs'.skarabox.packages.gen-knownhosts-file}/bin/gen-knownhosts-file \
            host_key.pub $ip $ssh_port $ssh_boot_port \
            > known_hosts
        '';

        # nix run .#install-on-beacon FLAKE [<command> ...]
        # nix run .#install-on-beacon
        # nix run .#install-on-beacon .#skarabox
        # nix run .#install-on-beacon .#skarabox -v
        install-on-beacon = pkgs.writeShellApplication {
          name = "install-on-beacon";
          runtimeInputs = [
            inputs'.skarabox.packages.install-on-beacon
          ];
          text = ''
            ip=${readFile ./ip}
            ssh_port=${readFile ./ssh_port}
            flake=$1
            shift

            install-on-beacon \
              -i $ip \
              -p $ssh_port \
              -f "$flake" \
              -k host_key \
              -s sops.key \
              -r .skarabox.disks.rootPassphrase \
              -d .skarabox.disks.dataPassphrase \
              -a "--ssh-option ConnectTimeout=10 -i ssh_skarabox $*"
          '';
        };

        unlock = pkgs.writeShellScriptBin "unlock" ''
          root_passphrase="$(SOPS_AGE_KEY_FILE=sops.key ${inputs'.nixpkgs.legacyPackages.sops}/bin/sops exec-file secrets.yaml "cat {} | ${pkgs.yq}/bin/yq -r .skarabox.disks.rootPassphrase")"
          printf "$root_passphrase" | ${self'.packages.boot-ssh}/bin/boot-ssh $@
        '';

        # nix run .#boot-ssh [<command> ...]
        # nix run .#boot-ssh
        # nix run .#boot-ssh echo hello
        boot-ssh = pkgs.writeShellScriptBin "boot-ssh" ''
          ${inputs'.skarabox.packages.ssh}/bin/ssh \
            "${readFile ./ip}" \
            "${readFile ./ssh_boot_port}" \
            root \
            -o UserKnownHostsFile=${./known_hosts} \
            -o ConnectTimeout=10 \
            -i ssh_skarabox \
            $@
        '';

        # nix run .#ssh [<command> ...]
        # nix run .#ssh
        # nix run .#ssh echo hello
        #
        # Note: the private SSH key is not read into the nix store on purpose.
        ssh = pkgs.writeShellScriptBin "ssh" ''
          ${inputs'.skarabox.packages.ssh}/bin/ssh \
            "${readFile ./ip}" \
            "${readFile ./ssh_port}" \
            ${self.nixosConfigurations.skarabox.config.skarabox.username} \
            -o UserKnownHostsFile=${./known_hosts} \
            -o ConnectTimeout=10 \
            -i ssh_skarabox \
            $@
        '';

        sops = pkgs.writeShellScriptBin "sops" ''
          SOPS_AGE_KEY_FILE=sops.key ${inputs'.nixpkgs.legacyPackages.sops}/bin/sops "$@"
        '';
      };

      apps = {
        deploy = inputs.deploy-rs.apps.x86_64-linux.deploy-rs;
      };
    };

    flake = let
      system = readFile ./system;
    in {
      nixosModules.skarabox = {
        imports = [
          skarabox.nixosModules.skarabox
          sops-nix.nixosModules.default
          ./configuration.nix
        ];
      };

      # Used with nixos-anywere for installation.
      nixosConfigurations.skarabox = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.skarabox
        ];
      };

      # Used with deploy-rs for updates.
      deploy.nodes.skarabox = let
        pkgs = import nixpkgs { inherit system; };

        # Taken from https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
        deployPkgs = import nixpkgs {
          inherit system;
          overlays = [
            deploy-rs.overlay
            (self: super: { deploy-rs = { inherit (pkgs) deploy-rs; lib = super.deploy-rs.lib; }; })
          ];
        };
      in {
        hostname = readFile ./ip;
        sshUser = self.nixosConfigurations.skarabox.config.skarabox.username;
        sshOpts = [
          "-o" "IdentitiesOnly=yes"
          "-o" "UserKnownHostsFile=${./known_hosts}"
          "-o" "ConnectTimeout=10"
          "-i" "ssh_skarabox"
          "-p" (readFile ./ssh_port)
          ""
        ];
        profiles = {
          system = {
            user = "root";
            path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.skarabox;
          };
        };
      };
      # From https://github.com/serokell/deploy-rs?tab=readme-ov-file#overall-usage
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
  });
}
