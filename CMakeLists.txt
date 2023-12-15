set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

cmake_minimum_required(VERSION 3.20)
project(opentitus)

find_package(SDL2 REQUIRED)
find_package(SDL2_mixer REQUIRED)

add_subdirectory(opl)

set(TITUS_SOURCES
    opentitus.c
    src/audio.c
    src/window.c
    src/draw.c
    src/enemies.c
    src/engine.c
    src/elevators.c
    src/fonts.c
    src/gates.c
    src/globals.c
    src/keyboard.c
    src/level.c
    src/menu.c
    src/objects.c
    src/original.c
    src/player.c
    src/reset.c
    src/scroll.c
    src/settings.c
    src/sprites.c
    src/sqz.c
    src/tituserror.c
    src/viewimage.c
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 11)

add_executable(opentitus ${TITUS_SOURCES})
target_include_directories(opentitus PRIVATE "src")
target_link_libraries(opentitus m opl SDL2::SDL2main SDL2::SDL2 SDL2::mixer)
if(MSVC)
    target_compile_options(opentitus PRIVATE "/W4")
else()
    target_compile_options(opentitus PRIVATE "-Wall")
endif()

install(PROGRAMS $<TARGET_FILE:opentitus> DESTINATION "titus")
install(PROGRAMS $<TARGET_FILE:opentitus> DESTINATION "moktar" RENAME "openmoktar${CMAKE_EXECUTABLE_SUFFIX}")
