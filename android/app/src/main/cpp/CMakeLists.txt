cmake_minimum_required(VERSION 3.18)
project(sotto_mp3 LANGUAGES C)

set(LAME_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lame-3.100)
file(GLOB LAME_SOURCES
  ${LAME_DIR}/libmp3lame/*.c
  ${LAME_DIR}/libmp3lame/mpglib/*.c
)

add_library(sotto_mp3 SHARED ${LAME_SOURCES})

target_include_directories(sotto_mp3 PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/config
  ${LAME_DIR}/include
  ${LAME_DIR}/libmp3lame
)

target_compile_definitions(sotto_mp3 PRIVATE HAVE_CONFIG_H=1)

target_compile_options(sotto_mp3 PRIVATE
  -O2
  -fPIC
  -Wno-implicit-function-declaration
  -Wno-int-conversion
  -Wno-incompatible-pointer-types
  -Wno-pointer-sign
  -Wno-unused-variable
)

target_link_libraries(sotto_mp3 m)
