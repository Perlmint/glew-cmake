# GLEW-cmake - nightly pre-generated snapshot with old unofficial cmake support

[GLEW](https://github.com/nigels-com/glew) is upstream of this project.
But *GLEW* repository does not contain generated sources. Only releases include generated sources.

*GLEW-cmake* has generated sources based on the latest *GLEW*. Sources are generated nightly.
If you need only the latest snapshot of *GLEW*, try the build system of *GLEW*. It is placed under the `build` directory. Official `CMakeLists.txt` is placed in `build/cmake`.
Please check [README_glew.md](./README_glew.md) for using build system of *GLEW*.

Also, *GLEW-cmake* has unofficial cmake support - It is created when the official CMake support of *GLEW* does not exist.
You can see some CMake script examples in [`glew-cmake`](./glew-cmake/) directory. But, I **strongly** recommend using official CMakeLists of *GLEW*.

## Usage

This project provide `libglew_static` and `libglew_shared` library targets and `glewinfo` and `visualinfo` executable targets.

`libglew_static` provides a static library, and `libglew_shared` provides a shared library.
*glew-cmake* does not affected by [BUILD_SHARED_LIBS](https://cmake.org/cmake/help/latest/variable/BUILD_SHARED_LIBS.html).

You can disable each library target by setting `glew-cmake_BUILD_SHARED` or `glew-cmake_BUILD_STATIC` falsy value (ex. `NO`, `FALSE`).

If you need only libraries, Please set `ONLY_LIBS` to `ON`. Otherwise, cmake generates executable targets also.

You can get pkg-config fils by setting `PKG_CONFIG_REPRESENTATIVE_TARGET` to `libglew_static` or `libglew_shared`.

Simply specify dependency of your target with `libglew_static` or `libglew_shared` by `target_link_libraries`.
It will set the additional include directory & the libraries to link to your target.

If you are not familiar with cmake, Some `sub-directory-test.cmake`, `fetch-content.cmake` in [`glew-cmake`](./glew-cmake/) could be helpful.
