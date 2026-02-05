{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages =
      forAllSystems
      (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.stdenv.mkDerivation rec {
            pname = "microsoft-azurevpnclient";
            version = "3.0.0";

            src = pkgs.fetchurl {
              url = "https://packages.microsoft.com/ubuntu/22.04/prod/pool/main/m/microsoft-azurevpnclient/microsoft-azurevpnclient_${version}_amd64.deb";
              hash = "sha256-nl02BDPR03TZoQUbspplED6BynTr6qNRVdHw6fyUV3s=";
            };

            renamedCerts = pkgs.runCommand "renamed-certs" {} ''
              mkdir -p $out/ssl/certs
              ${pkgs.lib.concatStringsSep "\n" (
                pkgs.lib.mapAttrsToList (name: _: ''
                  ${pkgs.openssl}/bin/openssl x509 -in ${pkgs.cacert.unbundled}/etc/ssl/certs/${name} -out \
                    $out/ssl/certs/${builtins.replaceStrings [".crt"] [".pem"] name} -outform PEM
                '') (builtins.readDir "${pkgs.cacert.unbundled}/etc/ssl/certs")
              )}
            '';

            runtimeDependencies = with pkgs; [zenity];

            nativeBuildInputs = with pkgs; [
              dpkg
              autoPatchelfHook
              makeWrapper
              libcap
            ];

            buildInputs = with pkgs; [
              zenity
              openssl
              gtk3
              libsecret
              cairo
              # libxcb
              nss
              bubblewrap
              nspr
              libuuid
              stdenv.cc.cc.lib
              at-spi2-core
              libdrm
              mesa
              gtk2
              glib
              pango
              atk
              curl
              cacert # Add this
              openvpn

              # cairo-xcb
              # libX11
              # libXcomposite
              # libXdamage
              # libXext
              # libXfixes
              # libXrandr
              # libxkbcommon
              # libxshmfence
            ];

            unpackPhase = ''
              dpkg-deb -x $src .
            '';

            # addAutoPatchelfSearchPath ${jre8}/lib/openjdk/jre/lib/
            # preBuild = ''
            #   addAutoPatchelfSearchPath opt/microsoft/microsoft-azurevpnclient/lib
            # '';

            # runtimeDependencies = [ "$out/lib" ];

            installPhase = ''
              mkdir -p $out
              cp -r opt $out
              cp -r usr/* $out

              mkdir -p $out/bin

              ln -s $out/opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient $out/bin/microsoft-azurevpnclient
              ln -s $out/opt/microsoft/microsoft-azurevpnclient/lib $out

              cp ${pkgs.writeShellScript "microsoft-azurevpnclient-wrapper" ''
                export PATH="${pkgs.openvpn}/bin:${pkgs.zenity}/bin:$PATH"
                export LD_LIBRARY_PATH="$out/lib:${nixpkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
                exec ${pkgs.bubblewrap}/bin/bwrap \
                  --dev-bind / / \
                  --bind ${renamedCerts}/ssl/certs /etc/ssl/certs \
                  $out/opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient "$@"
              ''} $out/bin/microsoft-azurevpnclient-inner
              chmod +x $out/bin/microsoft-azurevpnclient-inner

              # TODO:
              # Fix desktop file location
              # mkdir -p $out/share/applications
              # mv $out/share/applications/azurevpnclient.desktop $out/share/applications/
            '';

            meta = {
              description = "Microsoft Azure VPN Client";
              homepage = "https://azure.microsoft.com/en-us/services/vpn-gateway/";
              # TODO:
              # license = licenses.unfree;
              platforms = ["x86_64-linux"];
              maintainers = [];
            };
          };
        }
      );

    nixosModules.default = {
      config,
      pkgs,
      lib,
      ...
    }: {
      environment.systemPackages = [self.packages.${pkgs.system}.default];

      security.wrappers."microsoft-azurevpnclient-wrapped" = {
        owner = "root";
        group = "root";
        capabilities = "cap_net_admin+eip";
        source = "${self.packages.${pkgs.system}.default}/bin/microsoft-azurevpnclient-inner";
      };
    };
  };
}
