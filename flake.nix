{
  description = "Gimbal — a summoned overlay shell (no bar)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      flake.homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.gimbal;
        in
        {
          options.programs.gimbal = {
            enable = lib.mkEnableOption "Gimbal overlay shell";
            package = lib.mkOption {
              type = lib.types.package;
              default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              description = "Gimbal package (provides the `gimbal` command and its quickshell).";
            };
            devPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "/home/me/Projects/Gimbal";
              description = "Run QML from this working copy instead of the store, for live reload while hacking.";
            };
            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              example = { editor = "codium"; terminal = "foot"; };
              description = "Written to ~/.config/gimbal/config.json.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
            home.sessionVariables = lib.mkIf (cfg.devPath != null) { GIMBAL_REPO = cfg.devPath; };
            xdg.configFile."gimbal/config.json" = lib.mkIf (cfg.settings != { }) {
              text = builtins.toJSON cfg.settings;
            };
          };
        };

      perSystem = { pkgs, system, ... }:
        let
          qs = inputs.quickshell.packages.${system}.default.override {
            withWayland  = true;
            withX11      = false;
            withPipewire = true;
            withJemalloc = true;
            withQtSvg    = true;
          };

          # required for the shell to actually function
          runtimeDeps = with pkgs; [
            qs
            wl-clipboard # clipboard actions, screenshot copy
            cliphist # clipboard history
            imagemagick # wallpaper palette, wide-still cache
            ffmpeg # video wallpapers, poster frames
            grim # screenshots
            networkmanager # nmcli — network page
            bluez # bluetoothctl — bluetooth page
            brightnessctl # brightness (falls back to this if oledctl is absent)
            libnotify # quiet-screenshot toast
            xdg-utils # xdg-open fallback
          ];

          # soft deps — features degrade gracefully (command -v guarded) without them
          optionalDeps = with pkgs; [
            satty # screenshot annotation
            wl-screenrec # screen recording
            file # richer mime detection in the inspect card
            curl # weather on the clock page
          ];

          allDeps = runtimeDeps ++ optionalDeps;

          # QML import for video wallpapers; same nixpkgs (and so same Qt) as quickshell.
          qtmm = pkgs.kdePackages.qtmultimedia;
        in
        {
          packages.default =
            pkgs.runCommand "gimbal"
              { nativeBuildInputs = [ pkgs.makeWrapper ]; }
              ''
                mkdir -p $out/share/gimbal $out/bin
                cp -r ${./modules} $out/share/gimbal/modules
                cp -r ${./pages} $out/share/gimbal/pages
                cp -r ${./assets} $out/share/gimbal/assets
                cp ${./shell.qml} $out/share/gimbal/shell.qml
                cp ${./gimbal} $out/share/gimbal/gimbal
                chmod +x $out/share/gimbal/gimbal

                # GIMBAL_REPO is only a default so a working copy can be run instead (HM devPath).
                makeWrapper $out/share/gimbal/gimbal $out/bin/gimbal \
                  --set-default GIMBAL_REPO "$out/share/gimbal" \
                  --set QSG_RENDER_LOOP threaded \
                  --set-default QT_MEDIA_BACKEND ffmpeg \
                  --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "${qtmm}/lib/qt-6/qml" \
                  --prefix QML2_IMPORT_PATH : "${qtmm}/lib/qt-6/qml" \
                  --prefix QT_PLUGIN_PATH : "${qtmm}/lib/qt-6/plugins" \
                  --prefix PATH : "${pkgs.lib.makeBinPath allDeps}"
              ''
              // { meta.mainProgram = "gimbal"; };

          devShells.default = pkgs.mkShellNoCC {
            packages = allDeps;
            shellHook = ''
              export QSG_RENDER_LOOP=threaded
              echo "gimbal — run: ./gimbal start   (toggle: ./gimbal toggle)"
            '';
          };
        };
    };
}
