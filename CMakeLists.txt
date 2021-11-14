cmake_minimum_required(VERSION 2.8.12)

file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_MAJOR_STRING REGEX "GLEW_MAJOR[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MAJOR[ ]*=[ ]*([0-9]+)" "\\1" MAJOR_VERSION ${_VERSION_MAJOR_STRING})
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_MINOR_STRING REGEX "GLEW_MINOR[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MINOR[ ]*=[ ]*([0-9]+)" "\\1" MINOR_VERSION ${_VERSION_MINOR_STRING})
file(STRINGS ${CMAKE_CURRENT_SOURCE_DIR}/config/version  _VERSION_PATCH_STRING REGEX "GLEW_MICRO[ ]*=[ ]*[0-9]+.*")
string(REGEX REPLACE "GLEW_MICRO[ ]*=[ ]*([0-9]+)" "\\1" PATCH_VERSION ${_VERSION_PATCH_STRING})
set(GLEW_VERSION ${MAJOR_VERSION}.${MINOR_VERSION}.${PATCH_VERSION})

if(NOT CMAKE_VERSION VERSION_LESS 3.0)
	cmake_policy(SET CMP0048 NEW)
	project("glew" VERSION ${GLEW_VERSION} LANGUAGES C)
else()
	project("glew" C)
	set(CPACK_PACKAGE_VERSION_MAJOR ${MAJOR_VERSION})
	set(CPACK_PACKAGE_VERSION_MINOR ${MAJOR_VERSION})
	set(CPACK_PACKAGE_VERSION_PATCH ${MAJOR_VERSION})
endif()

set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(INCLUDE_DIR "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>$<INSTALL_INTERFACE:include>")
set(RC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/build)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin)

include("GeneratePkgConfig.cmake")

option(glew-cmake_BUILD_SHARED "Build the shared glew library" ON)
option(glew-cmake_BUILD_STATIC "Build the static glew library" ON)
option(USE_GLU "Use GLU" OFF)
option(GLEW_OSMESA "Off-screen Mesa mode" OFF)
option(PKG_CONFIG_REPRESENTATIVE_TARGET "Generate pc file for specified target as glew. libglew_static|libglew_shared" OFF)
option(ONLY_LIBS "Do not build executables" OFF)

set(LIBGLEW_SRCS ${SRC_DIR}/glew.c)

set(DEFINITIONS)
if(WIN32)
	list(APPEND DEFINITIONS -DWIN32_MEAN_AND_LEAN -DVC_EXTRALEAN -D_CRT_SECURE_NO_WARNINGS)
endif()

if(MSVC)
	list(APPEND LIBGLEW_SRCS ${RC_DIR}/glew.rc)
endif()

# Use namespaced libraries when supported
if(NOT CMAKE_VERSION VERSION_LESS 3.14)
	set(USE_NAMESPACED_LIB YES)
else()
	set(USE_NAMESPACED_LIB NO)
endif()

if(POLICY CMP0028)
	cmake_policy(SET CMP0028 NEW)
endif()

if(POLICY CMP0042)
	cmake_policy(SET CMP0042 NEW)
endif()

if(POLICY CMP0072)
	set(OpenGL_GL_PREFERENCE GLVND)
	if(NOT (WIN32 OR APPLE))
		set(USE_GLVND YES)
	else()
		# GLVND is not supported
		set(USE_GLVND NO)
	endif()
else()
	set(USE_GLVND NO)
endif()

find_package(OpenGL REQUIRED)

set(pc_requires)

if(NOT USE_GLU)
	list(APPEND DEFINITIONS -DGLEW_NO_GLU)
else()
	if(NOT OPENGL_GLU_FOUND)
		message(FATAL_ERROR "GLU is not found. but GLU option is enabled")
	endif()

	list(APPEND pc_requires glu)

	if(USE_NAMESPACED_LIB)
		list(APPEND LIBRARIES OpenGL::GLU)
	else()
		list(APPEND LIBRARIES ${OPENGL_glu_LIBRARY})
	endif()
endif()

list(APPEND pc_requires gl)
if(USE_NAMESPACED_LIB)
	if(USE_GLVND)
		list(APPEND LIBRARIES OpenGL::OpenGL)
	else()
		list(APPEND LIBRARIES OpenGL::GL)
	endif()
else()
	if(USE_GLVND)
		list(APPEND LIBRARIES ${OPENGL_opengl_LIBRARY})
	else()
		list(APPEND LIBRARIES ${OPENGL_gl_LIBRARY})
	endif()
endif()

# OS Specific dependencies
if(APPLE)
	find_library(AGL_LIBRARY AGL REQUIRED)
	list(APPEND LIBRARIES ${AGL_LIBRARY})
elseif(NOT WIN32)
	if(GLEW_OSMESA)
		find_library(OSMESA_LIBRARY OSMesa REQUIRED)
		list(APPEND LIBRARIES ${OSMESA_LIBRARY})
		list(APPEND DEFINITIONS -DGLEW_OSMESA)
		list(APPEND pc_requires osmesa)
	else()
		if(USE_GLVND)
			if(NOT OpenGL_GLX_FOUND)
				message(FATAL_ERROR "GLX is not found. Try with PREFER_GLVND=NO")
			endif()

			if(USE_NAMESPACED_LIB)
				list(APPEND LIBRARIES OpenGL::GLX)
			else()
				list(APPEND LIBRARIES ${OPENGL_glx_LIBRARY})
			endif()
		endif()
		
		find_package(X11 REQUIRED)

		list(APPEND pc_requires x11 xext)
		if(USE_NAMESPACED_LIB)
			list(APPEND LIBRARIES X11::X11 X11::Xext)
		else()
			list(APPEND LIBRARIES ${X11_X11_LIB} ${X11_Xext_LIB})
		endif()
	endif()
endif()

set(GLEW_TARGETS)

if(NOT CMAKE_INSTALL_LIBDIR)
	set(INSTALL_LIBDIR lib)
else()
	set(INSTALL_LIBDIR ${CMAKE_INSTALL_LIBDIR})
endif()

function(set_representative_target TARGET)
	set_target_properties(${TARGET} PROPERTIES
			OUTPUT_NAME "glew"
			DEBUG_POSTFIX d)

	# Windows & macOS use case-insensetive FS. do not create symbolic link
	if(NOT (WIN32 OR APPLE))
		get_target_property(TARGET_TYPE ${TARGET} TYPE)
		if(TARGET_TYPE STREQUAL STATIC_LIBRARY)
			set(EXT ".a")
			get_target_property(OUT_DIR ${TARGET} ARCHIVE_OUTPUT_DIRECTORY)
		else()
			set(EXT ".so")
			get_target_property(OUT_DIR ${TARGET} LIBRARY_OUTPUT_DIRECTORY)
		endif()
		if(NOT ${CMAKE_VERSION} VERSION_LESS 3.0)
			add_custom_command(TARGET ${TARGET} POST_BUILD
					COMMAND ${CMAKE_COMMAND} ARGS -E create_symlink libglew${EXT} libGLEW${EXT}
					WORKING_DIRECTORY ${OUT_DIR}
					BYPRODUCTS ${OUT_DIR}/libGLEW${EXT}
					COMMENT "create libGLEW symbolic link")
		else()
			add_custom_command(TARGET ${TARGET} POST_BUILD
					COMMAND bash ARGS -c "( test ! -e ${OUT_DIR}/libGLEW${EXT} && cd ${OUT_DIR} && ${CMAKE_COMMAND} -E create_symlink libglew${EXT} libGLEW${EXT} ) || true"
					COMMENT "create libGLEW symbolic link"
					VERBATIM)
		endif()

		if(NOT ${CMAKE_VERSION} VERSION_LESS 3.14)
			install(FILES ${OUT_DIR}/libGLEW${EXT} TYPE LIB)
		else()
			install(FILES ${OUT_DIR}/libGLEW${EXT} DESTINATION ${INSTALL_LIBDIR})
		endif()
	endif()
endfunction()

if(glew-cmake_BUILD_STATIC)
	add_library(libglew_static STATIC ${LIBGLEW_SRCS})

	set_representative_target(libglew_static)

	target_compile_definitions(libglew_static PUBLIC GLEW_STATIC)
	list(APPEND GLEW_TARGETS libglew_static)
endif()

if(glew-cmake_BUILD_SHARED)
	add_library(libglew_shared SHARED ${LIBGLEW_SRCS})

	if(glew-cmake_BUILD_STATIC)
		set_target_properties(libglew_shared PROPERTIES
			OUTPUT_NAME "glew-shared"
			DEBUG_POSTFIX d)
	else()
		set_representative_target(libglew_shared)
	endif()

	target_compile_definitions(libglew_shared PRIVATE GLEW_BUILD)
	if(MINGW)
		if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.13)
			target_link_options(libglew_shared PRIVATE -nostdlib)
		else()
			target_link_libraries(libglew_shared PRIVATE -nostdlib)
		endif()
	endif()
	list(APPEND GLEW_TARGETS libglew_shared)
endif()

foreach(GLEW_TARGET ${GLEW_TARGETS})
	target_compile_definitions(${GLEW_TARGET} PUBLIC ${DEFINITIONS})
	target_include_directories(${GLEW_TARGET} PUBLIC ${INCLUDE_DIR})
	target_link_libraries(${GLEW_TARGET} PUBLIC ${LIBRARIES})
	set_target_properties(${GLEW_TARGET} PROPERTIES VERSION ${GLEW_VERSION})
endforeach()

if(PKG_CONFIG_REPRESENTATIVE_TARGET)
	GeneratePkgConfigFile(${PKG_CONFIG_REPRESENTATIVE_TARGET} "The OpenGL Extension Wrangler library"
		NAME "glew"
		LIBRARY_DIR ${INSTALL_LIBDIR}
		REQUIRES ${pc_requires})
endif()

install(TARGETS ${GLEW_TARGETS} EXPORT glew-cmake
       ARCHIVE DESTINATION ${INSTALL_LIBDIR}
       LIBRARY DESTINATION ${INSTALL_LIBDIR})
install(EXPORT glew-cmake DESTINATION ${INSTALL_LIBDIR}/cmake/glew FILE glewConfig.cmake)

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
