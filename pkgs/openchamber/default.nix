{
  lib,
  buildNpmPackage,
  fetchzip,
  git,
  makeWrapper,
  nodejs_24,
  nix-update-script,
  openssh,
  opencode,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

buildNpmPackage (finalAttrs: {
  pname = "openchamber";
  version = "1.22.2";
  nodejs = nodejs_24;

  src = fetchzip {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-${finalAttrs.version}.tgz";
    hash = "sha256-2L8C5GIODcmxu1LYl80pPFLmPXtxJtbUJ2nZyiqh2qQ=";
    stripRoot = true;
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-oFeIw5j6q1kNWDMUwfZkiC1rh9lmb17a+mnmZhMBCQU=";

  dontNpmBuild = true;

  npmFlags = [
    "--no-audit"
    "--no-fund"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/openchamber \
      --prefix PATH : ${lib.makeBinPath [ git openssh opencode ]} \
      --set DISABLE_AUTOUPDATER 1 \
      --set npm_config_update_notifier false
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckProgramArg = "--version";
  versionCheckKeepEnvironment = [ "HOME" ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Desktop and web interface for OpenCode AI agent";
    homepage = "https://github.com/openchamber/openchamber";
    downloadPage = "https://www.npmjs.com/package/@openchamber/web";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    platforms = lib.platforms.linux;
  };
})