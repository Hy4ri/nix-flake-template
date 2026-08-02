{ lib, stdenv, fetchurl }:

# ─────────────────────────────────────────────────────────────────────
# Template package. Customize pname / src / meta.
# update-version.sh keeps `version` and `hash` in sync with version.json.
# ─────────────────────────────────────────────────────────────────────

stdenv.mkDerivation rec {
  pname = "myapp";                      # ← CHANGE THIS
  version = "0.1.0";                    # ← kept in sync by update-version.sh

  src = fetchurl {
    url = "https://github.com/OWNER/REPO/releases/download/v${version}/myapp-${version}.tar.gz";  # ← CHANGE THIS
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # ← filled by update-version.sh
  };

  installPhase = ''
    mkdir -p $out/bin
    install -m755 myapp $out/bin/myapp
  '';

  meta = {
    description = "My application";
    homepage = "https://example.com";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
