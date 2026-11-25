cmake_minimum_required(VERSION 3.21)
project(enclave-shell VERSION 0.1.0 LANGUAGES C CXX)

# Enclave Shell — Enclave's own desktop shell (Qt 6 / QML on Wayland).
# See docs/superpowers/specs/2026-11-24-enclave-shell-design.md

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network Svg)
# QML modules live under :/qt/qml/<URI> so loadFromModule() finds them.
qt_standard_project_setup(REQUIRES 6.5)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_get_variable(WAYLAND_SCANNER wayland-scanner wayland_scanner)

# wlr-foreign-toplevel-management: the task list and the bubble's window
# actions. Generated with plain wayland-scanner so the shell does not depend
# on Qt's private Wayland API.
set(WLR_PROTOCOLS_DIR "/usr/share/wlr-protocols" CACHE PATH "wlr-protocols XML dir")
set(FTL_XML "${WLR_PROTOCOLS_DIR}/unstable/wlr-foreign-toplevel-management-unstable-v1.xml")
set(GEN "${CMAKE_CURRENT_BINARY_DIR}/protocols")
file(MAKE_DIRECTORY "${GEN}")
add_custom_command(
  OUTPUT "${GEN}/wlr-foreign-toplevel-client.h" "${GEN}/wlr-foreign-toplevel.c"
  COMMAND "${WAYLAND_SCANNER}" client-header "${FTL_XML}" "${GEN}/wlr-foreign-toplevel-client.h"
  COMMAND "${WAYLAND_SCANNER}" private-code  "${FTL_XML}" "${GEN}/wlr-foreign-toplevel.c"
  DEPENDS "${FTL_XML}")

qt_add_executable(enclave-shell
  src/main.cpp
  src/theme.h src/theme.cpp
  src/appregistry.h src/appregistry.cpp
  src/iconprovider.h
  src/windowmanager.h
  src/toplevels.h src/toplevels.cpp
  src/system.h src/system.cpp
  "${GEN}/wlr-foreign-toplevel-client.h" "${GEN}/wlr-foreign-toplevel.c")
target_include_directories(enclave-shell PRIVATE "${GEN}" src)
# Fallback token location when running from a source checkout.
target_compile_definitions(enclave-shell PRIVATE
  ENCLAVE_SOURCE_TOKENS="${CMAKE_CURRENT_SOURCE_DIR}/../design-system/tokens/ember.json")

qt_add_qml_module(enclave-shell
  URI Enclave.Shell
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    qml/Wallpaper.qml
    qml/SearchWidget.qml
    qml/Spotlight.qml
    qml/Taskbar.qml
    qml/Widgets.qml
    qml/StartMenu.qml
    qml/Bubble.qml
    qml/Status.qml
    qml/ControlCenter.qml
    qml/CalendarPanel.qml
    qml/Settings.qml
    qml/settings/Controls.qml
    qml/settings/NetworkPage.qml
    qml/settings/SoundPage.qml
    qml/settings/DisplaysPage.qml
    qml/settings/AppearancePage.qml
    qml/settings/DesktopPage.qml
    qml/settings/NotificationsPage.qml
    qml/settings/PowerPage.qml
    qml/settings/ActivityPage.qml
    qml/settings/StoragePage.qml
    qml/settings/DateTimePage.qml
    qml/settings/KeyboardPage.qml
    qml/settings/AboutPage.qml
    qml/components/Glass.qml
    qml/components/Flyout.qml
    qml/components/Module.qml
    qml/components/ToggleRow.qml
    qml/components/EmberSlider.qml
    qml/components/EmberMenu.qml
    qml/components/HoverLabel.qml
    qml/components/DockItem.qml
    qml/components/WindowPeek.qml
    qml/components/IconButton.qml
    qml/components/AppTile.qml
    qml/components/SearchField.qml)

target_link_libraries(enclave-shell PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network Qt6::Svg PkgConfig::WAYLAND)

install(TARGETS enclave-shell RUNTIME DESTINATION bin)
