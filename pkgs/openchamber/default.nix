{
  lib,
  buildNpmPackage,
  fetchzip,
  git,
  makeWrapper,
  nodejs_22,
  nix-update-script,
  openssh,
  opencode,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

buildNpmPackage (finalAttrs: {
  pname = "openchamber";
  version = "1.22.0";
  nodejs = nodejs_22;

  src = fetchzip {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-${finalAttrs.version}.tgz";
    hash = "sha256-KJZy8gPSYgM3zjf/K1GW9eSgY4/q9i8qY1pJDxKpjRc=";
    stripRoot = true;
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-X8vMZApMUWO74gmlPtfRI5nQlhUHVLh/fms0I4wgEbo=";

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