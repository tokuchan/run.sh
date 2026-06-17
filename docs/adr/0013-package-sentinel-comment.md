# Package sentinel comment as insertion anchor for --add / --remove

`flake.nix` is Nix expression language — not TOML or JSON. There is no standard
POSIX-sh-accessible parser for it. Three approaches were considered for letting
`--add` and `--remove` edit the `packages = with pkgs; [ ... ]` list:

1. **Structural sed** — find the closing `];` of the packages block and insert
   before it. Works on the exact output of `--init-flake` but breaks silently if
   the user reformats the file, uses nested lists, or adds trailing comments.

2. **Nix AST tool** — use `nixpkgs-fmt`, `alejandra`, or a custom Nix script
   inside the container to do semantically-correct edits. No standard tool for
   in-place attribute-list editing exists; writing one is a significant scope
   increase and adds a container-startup round-trip with no other benefit.

3. **Sentinel comment** — `--init-flake` writes `# run:packages` inside the
   packages list. `--add` inserts a line above it; `--remove` deletes the target
   line. The user is told not to remove the sentinel. If it is absent, `--add`
   and `--remove` fail with a clear error rather than editing the wrong location.

Option 3 is chosen. It is robust against free-form edits to the rest of the file,
requires no external tools, and fails loudly rather than silently when the contract
is broken. The sentinel is an explicit, documented contract between `--init-flake`
and the package management flags — not hidden magic.

The cost is that users who remove the sentinel (or write their own `flake.nix`
without it) lose `--add` / `--remove` support and must edit manually. This is
acceptable: the flags are a convenience layer, not a requirement. The error message
directs them to add packages manually.
