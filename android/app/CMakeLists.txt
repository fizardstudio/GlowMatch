cmake_minimum_required(VERSION 3.22.1)

project("gl_mesh_engine")

# Compile our C++ engine files
add_library(
    gl_mesh_engine
    SHARED
    src/main/cpp/gl_mesh_engine.cpp
    src/main/cpp/gl_renderer.cpp
)

# Locate NDK system libraries
find_library(log-lib log)
find_library(gles3-lib GLESv3)
find_library(egl-lib EGL)

# Link the libraries
target_link_libraries(
    gl_mesh_engine
    ${log-lib}
    ${gles3-lib}
    ${egl-lib}
)
