# "Enclave Glass" Plasma color scheme — the signature dark warm glass with the
# orange #FF6A13 accent. The default Enclave theme.
{ pkgs }:
pkgs.writeTextDir "share/color-schemes/EnclaveGlass.colors" ''
  [General]
  Name=Enclave Glass
  ColorScheme=EnclaveGlass
  shadeSortColumn=true

  [Colors:Window]
  BackgroundNormal=20,16,23
  BackgroundAlternate=28,22,32
  ForegroundNormal=245,240,242
  ForegroundInactive=169,159,176
  ForegroundActive=255,106,19
  ForegroundLink=255,154,61
  ForegroundNegative=232,85,78
  ForegroundNeutral=242,183,5
  ForegroundPositive=25,169,116
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [Colors:View]
  BackgroundNormal=14,11,18
  BackgroundAlternate=22,18,28
  ForegroundNormal=245,240,242
  ForegroundInactive=150,140,158
  ForegroundActive=255,106,19
  ForegroundLink=255,154,61
  ForegroundNegative=232,85,78
  ForegroundNeutral=242,183,5
  ForegroundPositive=25,169,116
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [Colors:Button]
  BackgroundNormal=34,28,40
  BackgroundAlternate=28,22,32
  ForegroundNormal=245,240,242
  ForegroundInactive=169,159,176
  ForegroundActive=255,106,19
  ForegroundNegative=232,85,78
  ForegroundNeutral=242,183,5
  ForegroundPositive=25,169,116
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [Colors:Selection]
  BackgroundNormal=255,106,19
  BackgroundAlternate=230,96,24
  ForegroundNormal=28,15,4
  ForegroundInactive=255,220,190
  ForegroundActive=28,15,4
  ForegroundLink=40,20,8
  ForegroundNegative=90,20,16
  ForegroundNeutral=70,45,4
  ForegroundPositive=10,50,30
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [Colors:Tooltip]
  BackgroundNormal=28,22,32
  BackgroundAlternate=20,16,23
  ForegroundNormal=245,240,242
  ForegroundInactive=169,159,176
  ForegroundActive=255,106,19
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [Colors:Complementary]
  BackgroundNormal=20,16,23
  BackgroundAlternate=14,11,18
  ForegroundNormal=245,240,242
  ForegroundInactive=169,159,176
  ForegroundActive=255,106,19
  ForegroundLink=255,154,61
  ForegroundNegative=232,85,78
  ForegroundNeutral=242,183,5
  ForegroundPositive=25,169,116
  DecorationFocus=255,106,19
  DecorationHover=255,106,19

  [WM]
  activeBackground=28,22,32
  activeForeground=245,240,242
  activeBlend=255,106,19
  inactiveBackground=20,16,23
  inactiveForeground=150,140,158
  inactiveBlend=34,28,40

  [KDE]
  contrast=4
''
