{ pkgs, lib }:

let
  version = "1.4.4";
  releases = {
    aarch64-darwin = {
      archive = "bun-darwin-aarch64";
      hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
    };
    x86_64-linux = {
      archive = "bun-linux-x64";
      hash = "sha256-v4zL+ysLgBWeD5ptFcVTF63YB3U028YTCj7bUvzLOVw=";
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
    # Bun's own installer ships bunx as a link to bun, which reads argv[0].
    ln -s bun "$out/bin/bunx"
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
