cmake_minimum_required(VERSION 2.6)
project("glew")

set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)
set(RC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

include("GeneratePkgConfig.cmake")

option(glew-cmake_BUILD_SHARED "Build the shared glew library" ON)
option(glew-cmake_BUILD_STATIC "Build the static glew library" ON)
option(USE_GLU "Use GLU" OFF)
option(PKG_CONFIG_REPRESENTATIVE_TARGET "Generate pc file for specified target as glew. libglew_static|libglewmx_static|libglew_shared|libglewmx_shared" OFF)
option(ONLY_LIBS "Do not build executables" OFF)

file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_MAJOR_STRING REGEX "GLEW_MAJOR[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MAJOR[ ]*=[ ]*([0-9]+)" "\\1" CPACK_PACKAGE_VERSION_MAJOR ${_VERSION_MAJOR_STRING})
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_MINOR_STRING REGEX "GLEW_MINOR[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MINOR[ ]*=[ ]*([0-9]+)" "\\1" CPACK_PACKAGE_VERSION_MINOR ${_VERSION_MINOR_STRING})
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_PATCH_STRING REGEX "GLEW_MICRO[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MICRO[ ]*=[ ]*([0-9]+)" "\\1" CPACK_PACKAGE_VERSION_PATCH ${_VERSION_PATCH_STRING})
set(GLEW_VERSION ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH})

set(LIBGLEW_SRCS ${SRC_DIR}/glew.c)

set(DEFINITIONS)
if(WIN32)
	list(APPEND DEFINITIONS -DWIN32_MEAN_AND_LEAN -DVC_EXTRALEAN -D_CRT_SECURE_NO_WARNINGS)
endif()

if(MSVC)
	list(APPEND LIBGLEW_SRCS ${RC_DIR}/glew.rc)
endif()

find_package(OpenGL REQUIRED)

if(NOT USE_GLU)
	list(APPEND DEFINITIONS -DGLEW_NO_GLU)
	set(pc_requires)
else()
	set(pc_requires REQUIRES glu)
	list(APPEND LIBRARIES OpenGL::GLU)
	if(NOT OPENGL_GLU_FOUND)
		message(FATAL_ERROR "GLU is not found. but GLU option is enabled")
	endif()
endif( )

if(WIN32)
	list(APPEND LIBRARIES opengl32)
elseif(APPLE)
	find_library(GL_LIBRARY OpenGL)
	find_library(AGL_LIBRARY AGL)
	list(APPEND LIBRARIES ${GL_LIBRARY} ${AGL_LIBRARY})
else()
	list(APPEND LIBRARIES GL X11 dl Xext)
endif()

if(glew-cmake_BUILD_STATIC)
	add_library(libglew_static STATIC ${LIBGLEW_SRCS})

	set_target_properties(libglew_static PROPERTIES
		OUTPUT_NAME "glew"
		DEBUG_POSTFIX d)

	target_include_directories(libglew_static PUBLIC ${INCLUDE_DIR})
	target_compile_definitions(libglew_static PUBLIC GLEW_STATIC ${DEFINITIONS})
	target_link_libraries(libglew_static ${LIBRARIES} )
	set_target_properties(libglew_static PROPERTIES VERSION ${GLEW_VERSION})
	install(TARGETS libglew_static ARCHIVE DESTINATION lib)
endif()

if(glew-cmake_BUILD_SHARED)
	add_library(libglew_shared SHARED ${LIBGLEW_SRCS})

	set_target_properties(libglew_shared PROPERTIES
		OUTPUT_NAME "glew"
		DEBUG_POSTFIX d)

	target_compile_definitions(libglew_shared PUBLIC GLEW_BUILD ${DEFINITIONS})
	target_include_directories(libglew_shared PUBLIC ${INCLUDE_DIR})
	target_link_libraries(libglew_shared ${LIBRARIES})
	set_target_properties(libglew_shared PROPERTIES VERSION ${GLEW_VERSION})
	install(TARGETS libglew_shared
		ARCHIVE DESTINATION lib
		LIBRARY DESTINATION lib
		RUNTIME DESTINATION bin)
endif()

if(PKG_CONFIG_REPRESENTATIVE_TARGET)
	GeneratePkgConfigFile(${PKG_CONFIG_REPRESENTATIVE_TARGET} "The OpenGL Extension Wrangler library"
		NAME "glew"
		LIBRARY_DIR lib
		${pc_requires})
endif()

file(GLOB PUBLIC_HEADERS "include/GL/*.h")
install(FILES ${PUBLIC_HEADERS} DESTINATION include/GL/)

if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR} AND NOT ONLY_LIBS)
	set(GLEWINFO_SRCS ${SRC_DIR}/glewinfo.c)
	set(VISUALINFO_SRCS ${SRC_DIR}/visualinfo.c)
	if(MSVS)
		list(APPEND GLEWINFO_SRCS ${RC_DIR}/glewinfo.rc)
		list(APPEND VISUALINFO_SRCS ${RC_DIR}/visualinfo.rc)
	endif()

	add_executable(glewinfo ${GLEWINFO_SRCS})
	add_executable(visualinfo ${VISUALINFO_SRCS})

	if(glew-cmake_BUILD_STATIC)
		target_link_libraries(glewinfo libglew_static)
		target_link_libraries(visualinfo libglew_static)
	else()
		target_link_libraries(glewinfo libglew_shared)
		target_link_libraries(visualinfo libglew_shared)
	endif()

	install(TARGETS glewinfo visualinfo DESTINATION bin)
endif()
