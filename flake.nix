{
  description = "Warcraft 3 Reforged UI Designer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      electron_9 = pkgs.stdenv.mkDerivation {
        pname = "electron";
        version = "9.4.4";

        src = pkgs.fetchurl {
          url = "https://github.com/electron/electron/releases/download/v9.4.4/electron-v9.4.4-linux-x64.zip";
          hash = "sha256-eB1sqDTUFccQeOHCwZj6upJtb84Z4xRIu/RFCGkTVFA=";
        };

        nativeBuildInputs = with pkgs; [
          unzip
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          cairo
          cups
          dbus
          expat
          gdk-pixbuf
          glib
          gtk3
          libdrm
          libnotify
          libxkbcommon
          mesa
          nspr
          nss
          pango
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxshmfence
          libxtst
          libxscrnsaver
        ];

        runtimeDependencies = with pkgs; [
          mesa
          libGL
          systemd
        ];

        unpackPhase = ''
          unzip $src
        '';

        installPhase = ''
          mkdir -p $out/lib/electron $out/bin
          cp -r . $out/lib/electron/
          ln -s $out/lib/electron/electron $out/bin/electron
        '';
      };
    in
    {
      packages.${system}.default = pkgs.buildNpmPackage {
        pname = "wc3-ui-maker";
        version = "2.6.1";

        src = ./.;

        npmDepsHash = "sha256-YlmO2J9cwnL8ApXdi6G02kIFrylNv6dr7H/lj9lgRWM=";

        env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        # Fix case-sensitive imports (upstream targets Windows)
        postPatch = ''
          sed -i "s|from './Main'|from './main'|" src/ts/app.ts
          sed -i "s|from './Editor/Menus/contextMenu'|from './Editor/Menus/ContextMenu'|" src/ts/main.ts
          sed -i "s|from './Events/keyboardShortcuts'|from './Events/KeyboardShortcuts'|" src/ts/renderer.ts

          # Stub for gitignored analytics config
          echo 'export default { namespace: "", key: "" };' > src/ts/configMain.ts

          # Disable analytics fetch (countapi.xyz is dead)
          sed -i 's|fetch(`https://api.countapi|// fetch(`https://api.countapi|' src/ts/main.ts
        '';

        # Override build — upstream npm scripts use Windows-specific commands
        buildPhase = ''
          runHook preBuild

          npx tsc

          # Copy layout files (HTML, CSS, JS) into app/
          cp -r src/layout/* app/

          # Copy styles
          mkdir -p app/styles
          cp -r src/styles/* app/styles/

          # Copy static assets
          mkdir -p app/files
          cp -r files/* app/files/

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/wc3-ui-maker
          cp -r app node_modules package.json $out/lib/wc3-ui-maker/

          mkdir -p $out/bin
          makeWrapper ${electron_9}/bin/electron $out/bin/wc3-ui-maker \
            --add-flags "$out/lib/wc3-ui-maker/app/app.js"

          runHook postInstall
        '';

        meta = {
          description = "A visual UI maker for Warcraft 3 Reforged";
          license = pkgs.lib.licenses.cc0;
          platforms = [ "x86_64-linux" ];
          mainProgram = "wc3-ui-maker";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs
          electron_9
        ];

        ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
      };
    };
}
