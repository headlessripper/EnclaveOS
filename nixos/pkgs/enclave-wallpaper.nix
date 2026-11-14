# Enclave wallpaper: the logo centered on the brand dark background.
{ pkgs }:
pkgs.runCommand "enclave-wallpaper.png"
  { nativeBuildInputs = [ pkgs.imagemagick ]; }
  ''
    magick -size 1920x1080 xc:'#0B0E16' \
      \( ${../../assets/branding/light-orange-dot/1024x1024.png} -resize 440x440 \) \
      -gravity center -composite \
      $out
  ''
