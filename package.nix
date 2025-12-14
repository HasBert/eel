{
  vscode-utils,
  fetchFromGitHub,
  lib,
  src,
  version,
  ...
}:
vscode-utils.buildVscodeExtension rec {
  inherit src version;
  pname = "${vscodeExtName}";

  vscodeExtPublisher = "eclairevoyant";
  vscodeExtName = "eel";
  vscodeExtUniqueId = "${vscodeExtPublisher}.${vscodeExtName}";

  # repo root contains package.json
  sourceRoot = ".";

  installPhase = /* bash */ ''
    runHook preInstall

    mkdir -p "$out/$installPrefix"

    # find first package.json deterministically
    pkg="$(find . -maxdepth 2 -type f -name package.json -printf '%p\n' | LC_ALL=C sort | head -n1)"
    [ -n "$pkg" ] || { echo "package.json not found" >&2; exit 1; }
    dir="''${pkg%/*}"

    shopt -s dotglob
    mv "$dir"/* "$out/$installPrefix"/

    runHook postInstall
  '';
}
