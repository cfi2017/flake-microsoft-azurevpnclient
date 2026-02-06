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

            # Unbundle CA certificates into /etc/ssl/certs/ as clean PEM files.
            # The raw unbundled certs contain metadata and TRUSTED CERTIFICATE
            # blocks that aren't standard PEM — strip them to just the
            # -----BEGIN CERTIFICATE----- / -----END CERTIFICATE----- block.
            environment.etc =
              let
                cleanCerts = pkgs.runCommand "clean-ca-certs" { } ''
                  mkdir -p $out
                  for f in ${pkgs.cacert.unbundled}/etc/ssl/certs/*.crt; do
                    name="$(basename "$f" .crt).pem"
                    awk '/-----BEGIN CERTIFICATE-----/{p=1} p; /-----END CERTIFICATE-----/{exit}' \
                      "$f" > "$out/$name"
                  done
                '';
              in
              lib.mapAttrs' (
                name: _:
                lib.nameValuePair "ssl/certs/${name}" {
                  text = builtins.readFile "${cleanCerts}/${name}";
                }
              ) (builtins.readDir cleanCerts);
          };
        };
    };
}
