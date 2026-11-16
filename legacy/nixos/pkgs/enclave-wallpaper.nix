# Enclave wallpaper: the warm orange "bloom" — a glowing orange centre fading
# into deep plum, with the logo as a faint watermark.
{ pkgs }:
pkgs.runCommand "enclave-wallpaper.png"
  { nativeBuildInputs = [ pkgs.imagemagick ]; }
  ''
    magick -size 1920x1080 radial-gradient:'#FF7A1F'-'#1C1030' \
      \( ${../../assets/branding/light-orange-dot/1024x1024.png} -resize 420x420 \
         -alpha set -channel A -evaluate multiply 0.07 +channel \) \
      -gravity southeast -geometry +90+90 -composite \
      $out
  ''
