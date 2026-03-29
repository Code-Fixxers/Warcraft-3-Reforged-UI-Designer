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

          # Fix preload path: Electron 10+ requires absolute fs path, not file:// URL
          sed -i "s|preload: 'file://' + __dirname + 'preload.js'|preload: __dirname + '/preload.js'|" src/ts/main.ts

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
          makeWrapper ${pkgs.electron}/bin/electron $out/bin/wc3-ui-maker \
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
          pkgs.electron
        ];

        ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
      };
    };
}
