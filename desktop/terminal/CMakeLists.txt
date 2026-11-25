cmake_minimum_required(VERSION 3.21)
project(enclave-terminal VERSION 0.1.0 LANGUAGES CXX)

# Enclave Terminal — Enclave's own terminal: QTermWidget (the Konsole engine)
# in an Ember window — a tab strip that doubles as the title bar, the Enclave
# colour schemes in light and dark, roomy padding.

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Widgets)
find_package(qtermwidget6 REQUIRED)

qt_add_executable(enclave-terminal
  src/main.cpp
  src/terminalwindow.h src/terminalwindow.cpp
  resources.qrc)
target_compile_definitions(enclave-terminal PRIVATE
  ENCLAVE_SCHEMES_DIR="${CMAKE_INSTALL_PREFIX}/share/enclave/terminal"
  ENCLAVE_SOURCE_SCHEMES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/schemes")
target_link_libraries(enclave-terminal PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets qtermwidget6)

install(TARGETS enclave-terminal RUNTIME DESTINATION bin)
install(FILES schemes/Enclave-Dark.colorscheme schemes/Enclave-Light.colorscheme
        DESTINATION share/enclave/terminal)
install(FILES enclave-terminal.desktop DESTINATION share/applications)
