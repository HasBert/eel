{
  pkgs,
  testers,
  eelPkg,
  cases,
  ...
}:
let
  # vscode-dependencies for testing this package.
  tokenizer = pkgs.buildNpmPackage {
    pname = "eel-tokenizer-test";
    version = "0.1.0";
    src = ./tokenizer;
    # no build step needed for this package
    dontNpmBuild = true;
    npmDepsHash = "sha256-uJp4DFCb5kuSMEnb5ypkMmRZFNWVTFF/xIXslrqBtMI=";
  };

  scriptPath = "${tokenizer}/lib/node_modules/eel-tokenizer-test/tokenize-eel.js";
  nixGrammarPath = "${eelPkg}/share/vscode/extensions/eclairevoyant.eel/syntaxes/nix.embedded.tmLanguage.json";

  casesStr = pkgs.lib.strings.concatMapStringsSep "\n" (case: ''
    run_case(
      "${case.name}",
      "node ${scriptPath} ${nixGrammarPath} ${case.fixture} ${case.expect}",
      "${builtins.toString case.shouldFail}")
  '') cases;
in
testers.runNixOSTest {
  name = "eel-nix-embedded";
  nodes.machine =
    { ... }:
    {
      environment.systemPackages = [
        pkgs.nodejs
        tokenizer
      ];
    };
  testScript = /* python */ ''
    def run_case(name, cmd, should_fail):
      status, out = machine.execute(cmd)
      print(f"\n=== CASE: {name} ===")
      print(cmd)
      print(f"exit={status}")
      print(out)
      if should_fail:
          assert status != 0, "expected failure but it succeeded"
      else:
          assert status == 0, "expected success but it failed"

    ${casesStr}
  '';
}
