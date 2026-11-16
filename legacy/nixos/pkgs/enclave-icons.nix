# Enclave icon theme: inherits breeze-dark for full coverage, overrides the
# launcher / distributor logo with the Enclave mark at all standard sizes.
{ pkgs }:
let
  lib = pkgs.lib;
  logoDir = ../../assets/branding/light-orange-dot;
  sizes = [ "16" "32" "48" "64" "128" "256" "512" ];
  names = [ "start-here" "start-here-kde" "distributor-logo" "nix-snowflake" ];
  dirsList = lib.concatMapStringsSep "," (s: "${s}x${s}/apps") sizes;
  sections = lib.concatMapStringsSep "\n\n" (s: ''
    [${s}x${s}/apps]
    Size=${s}
    Context=Applications
    Type=Fixed'') sizes;
  index = ''
    [Icon Theme]
    Name=Enclave
    Comment=Enclave icon theme
    Inherits=breeze-dark,breeze,hicolor
    Directories=${dirsList}

    ${sections}
  '';
in
pkgs.runCommand "enclave-icons"
  {
    inherit index;
    passAsFile = [ "index" ];
    sizesStr = lib.concatStringsSep " " sizes;
    namesStr = lib.concatStringsSep " " names;
  }
  ''
    theme="$out/share/icons/Enclave"
    mkdir -p "$theme"
    cp "$indexPath" "$theme/index.theme"
    for s in $sizesStr; do
      mkdir -p "$theme/''${s}x''${s}/apps"
      for n in $namesStr; do
        cp ${logoDir}/''${s}x''${s}.png "$theme/''${s}x''${s}/apps/$n.png"
      done
    done
  ''
