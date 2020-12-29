cmake_minimum_required(VERSION 2.8.12)
project(sub_test)

add_subdirectory($ENV{GITHUB_WORKSPACE}/ glew_sub)
add_executable(glewinfo glewinfo.c)
target_link_libraries(glewinfo PRIVATE libglew_static)