{
  description = "Microsoft Azure VPN Client for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      microsoft-azurevpnclient = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        inherit microsoft-azurevpnclient;
        default = microsoft-azurevpnclient;
      };

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.microsoft-azurevpnclient;
          pkg = self.packages.${pkgs.stdenv.hostPlatform.system}.microsoft-azurevpnclient;
        in
        {
          options.programs.microsoft-azurevpnclient = {
            enable = lib.mkEnableOption "Microsoft Azure VPN Client";
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ pkg ];

            # Grant cap_net_admin to the main binary
            security.wrappers.microsoft-azurevpnclient = {
              source = "${pkg}/opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient";
              capabilities = "cap_net_admin+ep";
              owner = "root";
              group = "root";
            };

            # Unbundle CA certificates into /etc/ssl/certs/ so the client can find them.
            # Uses import-from-derivation on cacert.unbundled.
            environment.etc =
              let
                certsDir = pkgs.cacert.unbundled + "/etc/ssl/certs";
              in
              lib.mapAttrs' (
                name: _:
                let
                  pemName = builtins.replaceStrings [ ".crt" ] [ ".pem" ] name;
                in
                lib.nameValuePair "ssl/certs/${pemName}" {
                  text = builtins.readFile "${certsDir}/${name}";
                }
              ) (builtins.readDir certsDir);
          };
        };
    };
}
