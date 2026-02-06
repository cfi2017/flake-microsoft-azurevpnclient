{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  openssl,
  gtk3,
  libsecret,
  cairo,
  nss,
  nspr,
  libuuid,
  at-spi2-core,
  libdrm,
  mesa,
  gtk2,
  glib,
  pango,
  atk,
  curl,
  zenity,
  cacert,
  openvpn,
}:
stdenv.mkDerivation rec {
  pname = "microsoft-azurevpnclient";
  version = "3.0.0";

  src = fetchurl {
    url = "https://packages.microsoft.com/ubuntu/22.04/prod/pool/main/m/microsoft-azurevpnclient/microsoft-azurevpnclient_${version}_amd64.deb";
    hash = "sha256-nl02BDPR03TZoQUbspplED6BynTr6qNRVdHw6fyUV3s=";
  };

  runtimeDependencies = [zenity];

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    zenity
    openssl
    gtk3
    libsecret
    cairo
    nss
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
    cacert
    openvpn
  ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out
    cp -r opt $out
    cp -r usr/* $out
    mkdir -p $out/bin
    ln -s $out/opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient $out/bin/microsoft-azurevpnclient
    ln -s $out/opt/microsoft/microsoft-azurevpnclient/lib $out

    wrapProgram $out/bin/microsoft-azurevpnclient \
      --prefix PATH : "${openvpn}/bin" \
      --prefix PATH : "${zenity}/bin" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs} \
      --prefix LD_LIBRARY_PATH : "$out/lib"
  '';

  meta = {
    description = "Microsoft Azure VPN Client";
    homepage = "https://azure.microsoft.com/en-us/services/vpn-gateway/";
    platforms = ["x86_64-linux"];
    maintainers = [];
  };
}
