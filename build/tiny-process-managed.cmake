include(FetchContent)
FetchContent_Declare(
  tiny-process-library
  GIT_REPOSITORY https://gitlab.com/eidheim/tiny-process-library.git
  GIT_TAG        v2.0.2
  )
set(FETCHCONTENT_QUIET OFF)
FetchContent_MakeAvailable(tiny-process-library)