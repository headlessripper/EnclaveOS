# "Enclave Paper" Plasma color scheme — the light, warm Paper palette from
# Alpha Code (ac.css .t-paper), offered as a selectable Enclave theme.
{ pkgs }:
pkgs.writeTextDir "share/color-schemes/EnclavePaper.colors" ''
  [General]
  Name=Enclave Paper
  ColorScheme=EnclavePaper
  shadeSortColumn=true

  [Colors:Window]
  BackgroundNormal=247,246,243
  BackgroundAlternate=239,238,234
  ForegroundNormal=24,24,27
  ForegroundInactive=113,113,122
  ForegroundActive=217,134,28
  ForegroundLink=37,99,235
  ForegroundVisited=143,82,8
  ForegroundNegative=225,29,72
  ForegroundNeutral=196,122,22
  ForegroundPositive=77,124,15
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [Colors:View]
  BackgroundNormal=255,255,255
  BackgroundAlternate=251,250,248
  ForegroundNormal=24,24,27
  ForegroundInactive=113,113,122
  ForegroundActive=217,134,28
  ForegroundLink=37,99,235
  ForegroundNegative=225,29,72
  ForegroundNeutral=196,122,22
  ForegroundPositive=77,124,15
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [Colors:Button]
  BackgroundNormal=251,250,248
  BackgroundAlternate=239,238,234
  ForegroundNormal=24,24,27
  ForegroundInactive=113,113,122
  ForegroundActive=217,134,28
  ForegroundNegative=225,29,72
  ForegroundNeutral=196,122,22
  ForegroundPositive=77,124,15
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [Colors:Selection]
  BackgroundNormal=217,134,28
  BackgroundAlternate=196,122,22
  ForegroundNormal=255,255,255
  ForegroundInactive=251,235,211
  ForegroundActive=255,255,255
  ForegroundLink=37,99,235
  ForegroundNegative=225,29,72
  ForegroundNeutral=251,235,211
  ForegroundPositive=236,245,216
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [Colors:Tooltip]
  BackgroundNormal=21,21,23
  BackgroundAlternate=14,14,17
  ForegroundNormal=244,244,245
  ForegroundInactive=161,161,170
  ForegroundActive=217,134,28
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [Colors:Complementary]
  BackgroundNormal=21,21,23
  BackgroundAlternate=14,14,17
  ForegroundNormal=244,244,245
  ForegroundInactive=161,161,170
  ForegroundActive=217,134,28
  ForegroundLink=147,197,253
  ForegroundNegative=251,113,133
  ForegroundNeutral=250,215,160
  ForegroundPositive=190,242,100
  DecorationFocus=217,134,28
  DecorationHover=217,134,28

  [WM]
  activeBackground=251,250,248
  activeForeground=24,24,27
  activeBlend=217,134,28
  inactiveBackground=239,238,234
  inactiveForeground=113,113,122
  inactiveBlend=214,211,203

  [KDE]
  contrast=4
''
