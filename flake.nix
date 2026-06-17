{
  description = "run.sh — containerized command runner and its toolchain container";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        # ── Container image ────────────────────────────────────────────────
        # The project toolchain image: everything needed to run the test suite
        # and develop run.sh, inside a container.
        toolchain = pkgs.dockerTools.buildLayeredImage {
          name = "run-toolchain";
          tag  = "latest";

          contents = with pkgs; [
            # Runtime requirements of run.sh
            bash
            coreutils       # date, mktemp, readlink, dirname, id, …
            findutils       # find
            gnused          # sed (used in config parsing)
            gnugrep         # grep

            # VCS tools (run root detection)
            git

            # Test runner
            bats
          ];

          config = {
            Cmd        = [ "${pkgs.bash}/bin/bash" ];
            Env        = [ "PATH=/bin:/usr/bin" ];
            WorkingDir = "/workspace";
          };
        };

        default = self.packages.${system}.toolchain;
      };

      # ── Dev shell ──────────────────────────────────────────────────────
      # Primary toolchain: all tools needed to develop and test run.sh.
      # Consumed via 'nix develop' inside the container (run.sh devShell mode).
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          # Runtime requirements of run.sh
          bash
          coreutils       # date, mktemp, readlink, dirname, id, …
          findutils       # find
          gnused          # sed
          gnugrep         # grep
          util-linux      # script (PTY allocation for bats TTY tests)

          # VCS tools (run root detection)
          git

          # Test runner and linter
          bats
          shellcheck
        ];
      };
    };
}
