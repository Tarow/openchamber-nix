{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  nodejs_22,
  makeWrapper,
  electron,
  git,
  openssh,
  opencode,
  copyDesktopItems,
  makeDesktopItem,
  nix-update-script,
  commandLineArgs ? "",
}:

buildNpmPackage (finalAttrs: {
  pname = "openchamber-desktop";
  version = "1.22.0";
  nodejs = nodejs_22;

  src = fetchFromGitHub {
    owner = "openchamber";
    repo = "openchamber";
    rev = "v${finalAttrs.version}";
    hash = "sha256-oYdIysTvha06Ls2uZSlwR5Mm87ssicmmGPM4UsNx0yE=";
  };

  # The monorepo uses bun.lock; the npm workspace lockfile is committed in
  # ./package-lock.json and the root package.json is normalized (drop
  # packageManager, rewrite workspace: URLs, drop conflicting overrides) so
  # that `npm ci` inside buildNpmPackage resolves the same tree the lockfile
  # was generated from.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    chmod +w package-lock.json

    sed -i '/"packageManager":/d' package.json
    sed -i '/"overrides"/,/^  }/d' package.json
    sed -i -E 's/"workspace:[^"]*"/"*"/g' package.json packages/*/package.json
  '';

  npmDepsHash = "sha256-kxzQsv32IoJUmJM1NgFS3Y2kM6LpeioyAmzJ70qH/3w=";

  makeCacheWritable = true;

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  npmFlags = [
    "--ignore-scripts"
    "--no-audit"
    "--no-fund"
  ];

  nativeBuildInputs = [
    bun
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "openchamber";
      desktopName = "OpenChamber";
      genericName = "Desktop client for OpenCode AI agent";
      comment = "OpenChamber desktop client for OpenCode AI agent";
      exec = finalAttrs.pname;
      icon = "openchamber";
      terminal = false;
      categories = [ "Development" ];
      startupNotify = true;
      startupWMClass = "openchamber";
    })
  ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR

    # npm ci in the configure phase already populated node_modules (with
    # workspace .bin symlinks) in the source tree.
    patchShebangs node_modules packages

    bun run --cwd packages/electron build:web-assets
    bun run --cwd packages/electron bundle:main
    # Make the dev-mode resource root resolve relative to dist-bundle.
    ln -s ../resources packages/electron/dist-bundle/resources
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/${finalAttrs.pname}
    cp -r package.json packages node_modules $out/libexec/${finalAttrs.pname}/

    # Ensure the workspace dependency @openchamber/web resolves inside libexec
    mkdir -p $out/libexec/${finalAttrs.pname}/node_modules/@openchamber
    ln -sfn ../../packages/web $out/libexec/${finalAttrs.pname}/node_modules/@openchamber/web

    install -Dm644 packages/electron/resources/icons/app-icon.svg \
      $out/share/icons/hicolor/scalable/apps/openchamber.svg
    install -Dm644 packages/electron/resources/icons/icon.png \
      $out/share/icons/hicolor/512x512/apps/openchamber.png

    makeWrapper ${lib.getExe electron} $out/bin/${finalAttrs.pname} \
      --add-flags "$out/libexec/${finalAttrs.pname}/packages/electron" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --add-flags ${lib.escapeShellArg commandLineArgs} \
      --prefix PATH : ${lib.makeBinPath [ git openssh opencode ]} \
      --set NODE_ENV "production"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Electron desktop client for OpenCode AI agent";
    homepage = "https://github.com/openchamber/openchamber";
    downloadPage = "https://github.com/openchamber/openchamber/releases";
    license = lib.licenses.mit;
    mainProgram = finalAttrs.pname;
    platforms = lib.platforms.linux;
  };
})