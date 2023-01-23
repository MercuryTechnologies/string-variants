{
  description = "Library with various newtypes over Text helping maintain invariants";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig.allow-import-from-derivation = true; # cabal2nix uses IFD

  outputs = { self, nixpkgs, flake-utils }:
    let
      ghcVer = "ghc924";
      makeHaskellOverlay = overlay: final: prev: {
        haskell = prev.haskell // {
          packages = prev.haskell.packages // {
            ${ghcVer} = prev.haskell.packages."${ghcVer}".override (oldArgs: {
              overrides =
                prev.lib.composeExtensions (oldArgs.overrides or (_: _: { }))
                  (overlay prev);
            });
          };
        };
      };

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowBroken = true;
          };

        in
        {
          packages = rec {
            default = string-variants;
            string-variants = pkgs.haskell.packages.${ghcVer}.string-variants;
          };

          checks = {
            inherit (self.packages.${system}) string-variants;
          };

          # for debugging
          # inherit pkgs;

          devShells.default =
            let haskellPackages = pkgs.haskell.packages.${ghcVer};
            in
            haskellPackages.shellFor {
              packages = p: [ self.packages.${system}.string-variants ];
              withHoogle = true;
              buildInputs = with haskellPackages; [
                haskell-language-server
                fourmolu
                # ghcid
                cabal-install
                # fast-tags
              ] ++ (with pkgs; [
                sqlite
              ]);
              # Change the prompt to show that you are in a devShell
              # shellHook = "export PS1='\\e[1;34mdev > \\e[0m'";
            };
        };
    in
    flake-utils.lib.eachDefaultSystem out // {
      # this stuff is *not* per-system
      overlays = {
        default = makeHaskellOverlay (prev: hfinal: hprev:
          let hlib = prev.haskell.lib; in
          {
            string-variants = hprev.callCabal2nix "string-variants" ./. { };

            # here's how to do hacks to the package set
            # don't run the test suite
            # fast-tags = hlib.dontCheck hprev.fast-tags;
            #
            # don't check version bounds
            # friendly = hlib.doJailbreak hprev.friendly;
          });
      };
    };
}
