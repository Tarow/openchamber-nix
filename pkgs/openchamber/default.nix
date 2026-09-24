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
  version = "2.0.0";
  nodejs = nodejs_24;

  src = fetchzip {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-${finalAttrs.version}.tgz";
    hash = "sha256-e9kWWkDMUDRWXt/EFlq2LbKQPJgIB53hYs5Z7J4R6b8=";
    stripRoot = true;
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-0nS9ifgtAoJuGVC5eTPeLEApXCLApUCnLGZgnhrZzoY=";

  dontNpmBuild = true;

  npmFlags = [
    "--no-audit"
    "--no-fund"
  ];

  # The published npm tarball ships lifecycle scripts (prepack/build/dev) that
  # invoke `bun` against monorepo scripts not shipped in the tarball. The
  # npmInstallHook runs `npm pack --dry-run`, which triggers those scripts and
  # fails. Skip scripts only for the pack step; keep npmFlags free of
  # --ignore-scripts so `npm rebuild` still builds native deps (node-pty,
  # esbuild) in the configure phase.
  npmPackFlags = [
    "--ignore-scripts"
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