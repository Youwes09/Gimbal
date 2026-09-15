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

                makeWrapper $out/share/gimbal/gimbal $out/bin/gimbal \
                  --set GIMBAL_REPO "$out/share/gimbal" \
                  --set QSG_RENDER_LOOP threaded \
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
