{
  /****
   * A thoroughly commented Nix flake for a *Go* development environment.
   *
   * Goals
   * -----
   * - Pin `nixpkgs` so your toolchain (Go, gopls, linters, etc.) is reproducible.
   * - Provide a rich `devShell` via `nix develop` for day‑to‑day coding.
   * - Include common Go tools: gopls, goimports (via gotools), golangci-lint,
   *   staticcheck, delve, goreleaser, and helpers like gotests, gomodifytags.
   * - Show sane defaults for GOPATH/GOMODCACHE and CGO support.
   * - Offer `apps` so you can run `nix run .#lint` / `.#test` / `.#fmt` / `.#run`.
   *
   * How to use
   * ----------
   * 1) Save as `flake.nix` at your repo root, then run: `nix develop`.
   * 2) Inside the shell: `go version`, `gopls`, `golangci-lint`, `dlv`, etc.
   * 3) Optional: `nix run .#lint`, `nix run .#fmt`, `nix run .#test`, `nix run .#run`.
   *
   * Reasoning & Design
   * -------------------
   * - We stick to stock `nixpkgs` (no overlays) because Go tools are well covered.
   * - We set GOPATH/GOMODCACHE to a repo-local directory so module caches stay
   *   out of your git history and are easy to nuke.
   * - We include `pkg-config` and common native libs so CGO‑enabled builds are
   *   less surprising (adjust to your project’s actual needs).
   * - `apps` keep routine tasks reproducible across machines and CI.
   ****/

  description = "Reproducible Go development env with gopls, linters, and tools";

  inputs = {
    # Pin a nixpkgs branch. For long-lived projects, pin a commit for maximum determinism.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }: {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { allowUnfree = false; };
          staticcheck = (pkgs.staticcheck or null);
          maybe = p: if p == null then [ ] else [ p ];
          };

          # Pick the Go version for your team. `go` points to nixpkgs’ default;
          # you can pin a minor explicitly, e.g. pkgs.go_1_22 (or _1_23 when available).
          go = pkgs.go;

          # Core editor/analysis/debugging and QA tooling.
          gopls          = pkgs.gopls;          # language server for IDEs
          gotools        = pkgs.gotools;        # includes goimports, godoc, etc.
          golangciLint   = pkgs.golangci-lint;  # all-in-one linter aggregator
          staticcheck    = pkgs.staticcheck;    # extra static analysis
          delve          = pkgs.delve;          # debugger (dlv)
          goreleaser     = pkgs.goreleaser;     # release automation
          gotests        = pkgs.gotests;        # generate table-driven tests
          gomodifytags   = pkgs.gomodifytags;   # struct tag editing
          iferr          = pkgs.iferr;          # quick error handling snippets
          impl           = pkgs.impl;           # implement interfaces

          # Helpful for CGO or popular crates (OpenSSL/sqlite/zlib are common deps).
          nativeBuild = with pkgs; [
            pkg-config
            gcc
            openssl
            sqlite
            zlib
          ];

          # Common dev conveniences.
          devTools = with pkgs; [
            git
            bashInteractive
            which
            jq
            coreutils
            curl
          ];
        in {
          # `nix fmt` target for this flake (use your preferred nix formatter).
          formatter = pkgs.nixfmt-rfc-style or pkgs.nixfmt;

          devShells.default = pkgs.mkShell {
            name = "go-dev-shell";
            buildInputs = [
              go
              gopls
              gotools
              golangciLint
              delve
              goreleaser
              gotests
              gomodifytags
              iferr
              impl
            ] ++ nativeBuild ++ devTools;

            shellHook = ''
              echo "💡 Go dev shell active for ${system} — using $(go version)"

              # Keep module/download caches inside the repo (easy to clean, keeps $HOME tidy).
              export GOPATH="$PWD/.go"
              export GOMODCACHE="$GOPATH/pkg/mod"
              export GOCACHE="$GOPATH/cache"
              export PATH="$GOPATH/bin:$PATH"

              # Prefer local toolchain; avoid auto‑fetching toolchains in Go 1.21+.
              export GOTOOLCHAIN=local

              # CGO discovery for common libs. Adjust/remove if unused.
              export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.sqlite.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig"

              # Helpful defaults for reproducible builds.
              export CGO_ENABLED=1
            '';
          };

          # Small helper apps so CI/dev can run common tasks without bespoke scripts.
          apps = {
            fmt = {
              type = "app";
              program = toString (pkgs.writeShellScript "go-fmt" ''
                set -euo pipefail
                exec ${go}/bin/go fmt ./...
              '');
            };

            lint = {
              type = "app";
              program = toString (pkgs.writeShellScript "go-lint" ''
                set -euo pipefail
                if [ -f .golangci.yml ] || [ -f .golangci.yaml ] || [ -f .golangci.toml ]; then
                  exec ${golangciLint}/bin/golangci-lint run
                else
                  echo "(no golangci-lint config found — running with defaults)" >&2
                  exec ${golangciLint}/bin/golangci-lint run --timeout=5m
                fi
              '');
            };

            vet = {
              type = "app";
              program = toString (pkgs.writeShellScript "go-vet" ''
                set -euo pipefail
                exec ${go}/bin/go vet ./...
              '');
            };

            test = {
              type = "app";
              program = toString (pkgs.writeShellScript "go-test" ''
                set -euo pipefail
                exec ${go}/bin/go test ./... -count=1
              '');
            };

            run = {
              type = "app";
              program = toString (pkgs.writeShellScript "go-run" ''
                set -euo pipefail
                # Run your main module (override as needed).
                exec ${go}/bin/go run ./...
              '');
            };
          };

          # NOTE on `checks`:
          # Running `go test` or `golangci-lint` as *Nix builds* will fail without
          # vendored deps or gomod2nix because Nix builds lack network access.
          # If you want fully offline, reproducible CI checks, consider gomod2nix
          # (or vendoring) and then wire those here. For now, we only lint the flake.
          checks.nixfmt = pkgs.runCommand "check-nixfmt" { buildInputs = [ (pkgs.nixfmt-rfc-style or pkgs.nixfmt) ]; } ''
            ${pkgs.lib.getExe (pkgs.nixfmt-rfc-style or pkgs.nixfmt)} ${self}/flake.nix
            touch $out
          '';
        };
    });
}
