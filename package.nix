{ lib, stdenvNoCC, fetchurl }:

# Working single-platform example. Change the package, URL and metadata
# when creating a new flake. update-version.sh updates version and hash.
stdenvNoCC.mkDerivation rec {
  pname = "jq";
  version = "1.8.2";

  src = fetchurl {
    url = "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-linux-amd64";
    hash = "sha256-scIhct0wPzvknpNapWqkiot6RuC8g4tJl9O7RRSVhw8=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 "$src" "$out/bin/jq"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/jq" --version)" = "jq-${version}"
    test "$(echo '{"answer": 42}' | "$out/bin/jq" '.answer')" = "42"
    runHook postInstallCheck
  '';

  meta = {
    description = "Lightweight and flexible command-line JSON processor";
    homepage = "https://jqlang.org";
    license = lib.licenses.mit;
    mainProgram = "jq";
    platforms = [ "x86_64-linux" ];
  };
}
