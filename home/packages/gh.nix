{ pkgs, lib }:

let
  version = "2.105.0";
  releases = {
    aarch64-darwin = {
      archive = "gh_${version}_macOS_arm64";
      extension = "zip";
      hash = "sha256-Kl0DEDrkRJJzg7k9n/1lV5om4uuQDOHPEfVSWNUxne0=";
    };
    x86_64-linux = {
      archive = "gh_${version}_linux_amd64";
      extension = "tar.gz";
      hash = "sha256-eeerXbc4xId3tpbjdPi0KPBkfev7Qk9E0vQmNwQH/i8=";
    };
  };
  release =
    releases.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported GitHub CLI platform: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "gh";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/cli/cli/releases/download/v${version}/${release.archive}.${release.extension}";
    inherit (release) hash;
  };

  nativeBuildInputs = [ pkgs.installShellFiles ] ++ lib.optionals (release.extension == "zip") [ pkgs.unzip ];
  sourceRoot = release.archive;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/gh "$out/bin/gh"
    installManPage share/man/man1/*.1
    installShellCompletion --cmd gh \
      --bash <("$out/bin/gh" completion -s bash) \
      --fish <("$out/bin/gh" completion -s fish) \
      --zsh <("$out/bin/gh" completion -s zsh)
    runHook postInstall
  '';

  meta = {
    description = "GitHub CLI tool";
    homepage = "https://cli.github.com";
    license = lib.licenses.mit;
    mainProgram = "gh";
    platforms = builtins.attrNames releases;
  };
}
