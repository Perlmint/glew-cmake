cmake_minimum_required(VERSION 2.8.12)
project(cmake_install_test)

# Dependencies of glew.
# These are referenced in glewConfig.cmake. but, not automatically found.
find_package(OpenGL REQUIRED)
find_package(X11 REQUIRED)

find_package(glew)
add_executable(glewinfo glewinfo.c)
target_link_libraries(glewinfo PRIVATE libglew_static)
