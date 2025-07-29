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

      # Platform-specific download URLs and hashes
      platforms = {
        x86_64-linux = {
          url = "https://github.com/Control-D-Inc/ctrld/releases/download/v${version}/ctrld_${version}_linux_amd64.tar.gz";
          name = "ctrld_${version}_linux_amd64";
          sha256 = "sha256-93OD+Ei268OmQ5GIu5pT4eQCNbWWGdMC8vfWvuqmxqk=";
        };

        aarch64-linux = {
          url = "https://github.com/Control-D-Inc/ctrld/releases/download/v${version}/ctrld_${version}_linux_arm64.tar.gz";
          name = "ctrld_${version}_linux_arm64";
          sha256 = "sha256-2pm2mls5E2HEfUxSx1sJHg5mUs7qMpgsE0phXBPKfVo=";
        };
        x86_64-darwin = {
          url = "https://github.com/Control-D-Inc/ctrld/releases/download/v${version}/ctrld_${version}_darwin_amd64.tar.gz";
          name = "ctrld_${version}_darwin_amd64";
          sha256 = "sha256-sw1B0QfBoKni1NxccUNw5yoc5jVDPvP356zICpeveXc=";
        };
        aarch64-darwin = {
          url = "https://github.com/Control-D-Inc/ctrld/releases/download/v${version}/ctrld_${version}_darwin_arm64.tar.gz";
          name = "ctrld_${version}_darwin_arm64";
          sha256 = "sha256-ti1PO2ZqZfmy4s1d7ogXg+uwxuzZOxOmmkf4xYNXGMk=";
        };
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          platform = platforms.${system};
        in
        {
          ctrld = pkgs.stdenv.mkDerivation rec {
            pname = "ctrld";
            inherit version;

            src = pkgs.fetchurl {
              url = platform.url;
              sha256 = platform.sha256;
            };

            nativeBuildInputs = [
              pkgs.gnutar
              pkgs.gzip
            ];

            unpackPhase = ''
              runHook preUnpack
              tar -xzf $src
              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp dist/${platform.name}/ctrld $out/bin/
              chmod +x $out/bin/ctrld
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A highly configurable, multi-protocol DNS forwarding proxy";
              homepage = "https://github.com/Control-D-Inc/ctrld";
              license = licenses.mit;
              maintainers = [ ];
              platforms = [ system ];
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
          configFile = toml.generate "config.toml" cfg.settings;
        in
        {
          options.services.ctrld = {
            enable = lib.mkEnableOption "ctrld DNS proxy";

            settings = lib.mkOption {
              type = toml.type;
              default = { };
              description = "Configuration settings for ctrld";
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
                "nss-lookup.target"
              ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                ExecStart = "${pkgs.lib.getExe cfg.package} run --config=${configFile}";
                Restart = "always";
                RestartSec = 10;
                DynamicUser = true;

                AmbientCapabilities = "CAP_NET_BIND_SERVICE";
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                NoNewPrivileges = true;
                ProtectClock = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                RemoveIPC = true;
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
                SystemCallErrorNumber = "EPERM";
                SystemCallFilter = [
                  "@system-service"
                  "~@privileged @resources"
                ];
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
          configFile = toml.generate "config.toml" cfg.settings;
        in
        {
          options.services.ctrld = {
            enable = lib.mkEnableOption "ctrld DNS proxy";

            settings = lib.mkOption {
              type = toml.type;
              default = { };
              description = "Configuration settings for ctrld";
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
