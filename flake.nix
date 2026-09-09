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

          fonts = pkgs.makeFontsConf {
            fontDirectories = with pkgs; [ inter nerd-fonts.fira-code ];
          };
        in
        {
          packages.default =
            pkgs.runCommand "gimbal" { buildInputs = [ pkgs.makeWrapper ]; } ''
              mkdir -p $out/bin
              makeWrapper ${qs}/bin/qs $out/bin/gimbal \
                --set FONTCONFIG_FILE "${fonts}" \
                --set QSG_RENDER_LOOP threaded \
                --add-flags "-p \$PWD"
            '';

          devShells.default = pkgs.mkShellNoCC {
            packages = [ qs ];
            shellHook = ''
              export FONTCONFIG_FILE="${fonts}"
              export QSG_RENDER_LOOP=threaded
              echo "gimbal — run: ./gimbal start   (toggle: ./gimbal toggle)"
            '';
          };
        };
    };
}
