# Enclave Glass global theme (Plasma look-and-feel). Installed system-wide and
# set as the default, so the colour scheme, icons, accent, wallpaper, panel and
# splash all apply on FIRST boot — no per-user login needed.
{ pkgs, ... }:
let
  wallpaper = pkgs.callPackage ./enclave-wallpaper.nix { };

  metadata = pkgs.writeText "metadata.json" ''
    {
      "KPackageStructure": "Plasma/LookAndFeel",
      "KPlugin": {
        "Authors": [{ "Name": "Enclave" }],
        "Id": "org.enclave.glass",
        "Name": "Enclave Glass",
        "License": "MIT"
      }
    }
  '';

  defaults = pkgs.writeText "defaults" ''
    [kdeglobals][General]
    ColorScheme=EnclaveGlass
    AccentColor=255,106,19

    [kdeglobals][Icons]
    Theme=Enclave

    [kdeglobals][KDE]
    widgetStyle=Breeze

    [Wallpaper]
    Image=${wallpaper}

    [kwinrc][org.kde.kdecoration2]
    library=org.kde.breeze

    [ksplashrc][KSplash]
    Engine=none
    Theme=None
  '';

  layout = pkgs.writeText "org.kde.plasma.desktop-layout.js" ''
    var panel = new Panel;
    panel.location = "bottom";
    panel.height = 44;
    panel.floating = true;
    panel.addWidget("org.kde.plasma.kickoff");
    panel.addWidget("org.kde.plasma.icontasks");
    panel.addWidget("org.kde.plasma.marginsseparator");
    panel.addWidget("org.kde.plasma.systemtray");
    panel.addWidget("org.kde.plasma.digitalclock");
    var ds = desktops();
    for (var i = 0; i < ds.length; i++) {
      ds[i].wallpaperPlugin = "org.kde.image";
      ds[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
      ds[i].writeConfig("Image", "file://${wallpaper}");
    }
  '';
in
pkgs.runCommand "enclave-lookandfeel" { } ''
  d="$out/share/plasma/look-and-feel/org.enclave.glass"
  mkdir -p "$d/contents/layouts"
  cp ${metadata} "$d/metadata.json"
  cp ${defaults} "$d/contents/defaults"
  cp ${layout}   "$d/contents/layouts/org.kde.plasma.desktop-layout.js"
''
