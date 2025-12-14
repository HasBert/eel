# Flake

To build and test reproducible.

## Prerequisites

-   nix is installed.
-   nix flakes are enabled.

## packages

## checks (Nixos tests)

Uses a tokenizer js script `tests/tokenizer/tokenize-eel.js`(generated mainly by chatgpt 5.2), which imports `vscode-textmate` + `vscode-oniguruma` and runs the actual tests in node. Because we only use the shell to execute test and not vscode (which would usally provide the `source.shell` or `source.css` tags), we use the `tests/tokenizer/grammars` to provide a basic grammar recognition like with vscode.

### Executing Tests

```bash
# local files
nix build .#checks.x86_64-linux.eel-local
# with logs
nix build .#checks.x86_64-linux.eel-local -L
# commit c6
nix build .#checks.x86_64-linux.eel-c6237da -L
# commit 3c
nix build .#checks.x86_64-linux.eel-3cd0542 -L
```
