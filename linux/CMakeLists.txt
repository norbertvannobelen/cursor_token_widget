cmake_minimum_required(VERSION 3.16)

project(cursor-tokens VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Kirigami)

add_executable(cursor-tokens-app
    app/main.cpp
    app/Backend.cpp
    app/Backend.hpp
)

target_link_libraries(cursor-tokens-app PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

install(TARGETS cursor-tokens-app DESTINATION ${KDE_INSTALL_BINDIR})
install(FILES app/qml/Main.qml DESTINATION ${KDE_INSTALL_DATADIR}/cursor-tokens)
