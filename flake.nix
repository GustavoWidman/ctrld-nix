{
  description = "Control-D ctrld DNS proxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      version = "1.4.5";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          ctrld = pkgs.buildGoModule rec {
            name = "ctrld";
            inherit version;

            src = pkgs.fetchFromGitHub {
              owner = "Control-D-Inc";
              repo = "ctrld";
              rev = "v${version}";
              hash = "sha256-ZiNyB8d4x6SBG5MIGqzHzQgFbMCRunPPpGKzffwmXBM=";
            };

            vendorHash = "sha256-AVR+meUcjpExjUo7J1U6zUPY2B+9NOqBh7K/I8qrqL4=";
            proxyVendor = true;
            subPackages = [ "cmd/ctrld" ];

            meta = with pkgs.lib; {
              description = "A highly configurable, multi-protocol DNS forwarding proxy";
              homepage = "https://github.com/Control-D-Inc/ctrld";
              license = licenses.mit;
              maintainers = [ ];
              platforms = [ system ];
              mainProgram = "ctrld";
            };
          };

          default = self.packages.${system}.ctrld;
        }
      );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.ctrld;

          toml = pkgs.formats.toml { };
          configFile =
            if lib.isPath cfg.settings || lib.isString cfg.settings then
              cfg.settings
            else
              toml.generate "ctrld.toml" cfg.settings;
        in
        {
          options.services.ctrld = {
            enable = lib.mkEnableOption "Enable ctrld DNS proxy";

            settings = lib.mkOption {
              type = with lib.types; either path toml.type;
              default = {
                listener = {
                  "0" = {
                    ip = "0.0.0.0";
                    port = 53;
                  };
                };
                upstream = {
                  "0" = {
                    type = "doh";
                    endpoint = "https://freedns.controld.com/p2";
                    timeout = 5000;
                  };
                };
              };
              description = "Configuration settings for ctrld. Accepts path to a TOML file.";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.ctrld;
              description = "ctrld package to use";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.ctrld = {
              description = "Control-D DNS Proxy";
              after = [
                "network.target"
              ];
              before = [ "nss-lookup.target" ];
              wantedBy = [ "multi-user.target" ];
              restartTriggers = [ cfg.package ];

              serviceConfig = {
                Type = "exec";
                Restart = "always";
                RestartSec = 5;

                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ "/var/run" ];

                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                  "AF_NETLINK"
                ];
                AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                SystemCallArchitectures = "native";
                SystemCallFilter = [
                  "@system-service"
                  "~@privileged @resources"
                ];

                MemoryDenyWriteExecute = true;
                ProtectControlGroups = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectClock = true;

                RestrictNamespaces = true;
                RestrictRealtime = true;
                PrivateDevices = true;
                LockPersonality = true;

                NoNewPrivileges = true;
                RestrictSUIDSGID = true;

                ExecStart = "${pkgs.lib.getExe cfg.package} run --config=${configFile}";
              };
            };
          };
        };

      darwinModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.ctrld;

          toml = pkgs.formats.toml { };
          configFile =
            if lib.isPath cfg.settings || lib.isString cfg.settings then
              cfg.settings
            else
              toml.generate "ctrld.toml" cfg.settings;
        in
        {
          options.services.ctrld = {
            enable = lib.mkEnableOption "Enable ctrld DNS proxy";

            settings = lib.mkOption {
              type = with lib.types; either path toml.type;
              default = {
                listener = {
                  "0" = {
                    ip = "0.0.0.0";
                    port = 53;
                  };
                };
                upstream = {
                  "0" = {
                    type = "doh";
                    endpoint = "https://freedns.controld.com/p2";
                    timeout = 5000;
                  };
                };
              };
              description = "Configuration settings for ctrld. Accepts path to a TOML file.";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.ctrld;
              description = "ctrld package to use";
            };
          };

          config = lib.mkIf cfg.enable {
            launchd.daemons.ctrld = {
              command = "${pkgs.lib.getExe cfg.package} run --config=${configFile}";
              serviceConfig = {
                KeepAlive = true;
                RunAtLoad = true;
                StandardOutPath = "/var/log/ctrld.log";
                StandardErrorPath = "/var/log/ctrld.log";
              };
            };
          };
        };
    };
}
