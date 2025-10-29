{
  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            packages = [
              bash
              python3
              opentofu
              claude-code
              jq
              curl
              direnv
            ];

            shellHook = ''
              alias tf=tofu
              direnv allow
            '';
          };
      }
    );
}
