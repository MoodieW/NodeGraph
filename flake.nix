{
  description = "Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Add packages here
            odin
            ols
            glfw
            vulkan-headers
            vulkan-loader
            vulkan-validation-layers
            shader-slang # Slang shader compiler
          ];

          shellHook = ''
            echo "Dev environment loaded"
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.gcc.cc]}:$PWD/editor/deps/odin-slang/slang/lib:$LD_LIBRARY_PATH
          '';
        };
      }
    );
}
