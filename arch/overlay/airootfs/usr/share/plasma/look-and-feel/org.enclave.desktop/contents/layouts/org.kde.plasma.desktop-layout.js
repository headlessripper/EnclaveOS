/* Enclave default desktop layout — a Windows-11-familiar bottom taskbar, but
 * cleaner: Enclave start button, centered task icons, tray + clock at the right.
 * The signature floating control bubble is provided separately (KWin), not here.
 */
var panel = new Panel;
panel.location = "bottom";
panel.height = 44;
panel.floating = false;
panel.lengthMode = "fill";

// flexible spacer -> centers the start+tasks group
var leftPad = panel.addWidget("org.kde.plasma.panelspacer");
leftPad.currentConfigGroup = ["General"];
leftPad.writeConfig("expanding", true);

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "/usr/share/enclave/enclave-logo.svg");

panel.addWidget("org.kde.plasma.icontasks");

// flexible spacer -> pushes the tray/clock to the right edge
var rightPad = panel.addWidget("org.kde.plasma.panelspacer");
rightPad.currentConfigGroup = ["General"];
rightPad.writeConfig("expanding", true);

panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");

// Enclave wallpaper on every screen.
var all = desktops();
for (var i = 0; i < all.length; i++) {
  all[i].wallpaperPlugin = "org.kde.image";
  all[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  all[i].writeConfig("Image", "file:///usr/share/enclave/wallpapers/enclave-default.svg");
}
