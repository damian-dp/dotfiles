{ pkgs, lib }:

let
  version = "1.4.0";
  releases = {
    aarch64-darwin = {
      archive = "bun-darwin-aarch64";
      hash = "sha256-xmnpf2Fk4cluBwF0jbmN+ndJKQjL2DlMdVcTSnNd44E=";
    };
    x86_64-linux = {
      archive = "bun-linux-x64";
      hash = "sha256-LQP7X7g6yLVnrKCigbLOGhoZ1Ij1bClo2Iw/Jekv5FI=";
    };
  };
  release =
    releases.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported Bun platform: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "bun";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/${release.archive}.zip";
    inherit (release) hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];
  sourceRoot = release.archive;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bun "$out/bin/bun"
    runHook postInstall
  '';

  meta = {
    description = "Incredibly fast JavaScript runtime, bundler, test runner, and package manager";
    homepage = "https://bun.com";
    license = lib.licenses.mit;
    mainProgram = "bun";
    platforms = builtins.attrNames releases;
  };
}
