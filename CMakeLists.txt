cmake_minimum_required(VERSION 3.21)

project(QtCalendarApp VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS
  Core
  Gui
  Qml
  Quick
  QuickControls2
  Network
)

qt_standard_project_setup()

qt_add_executable(QtCalendarApp
  src/app/main.cpp
  src/backend/WorkoutStore.cpp
  resources/resources.qrc
)

target_include_directories(QtCalendarApp PRIVATE src)

target_link_libraries(QtCalendarApp PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::QuickControls2
  Qt6::Network
)

set_target_properties(QtCalendarApp PROPERTIES
  MACOSX_BUNDLE TRUE
)

if (WIN32)
  find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS
    "$ENV{QTDIR}/bin"
    "C:/Qt/6.10.2/msvc2022_64/bin"
    "C:/Qt/6.8.3/msvc2022_64/bin"
  )

  if (WINDEPLOYQT_EXECUTABLE)
    add_custom_command(TARGET QtCalendarApp POST_BUILD
      COMMAND "${WINDEPLOYQT_EXECUTABLE}"
              --no-translations
              --qmldir "${CMAKE_SOURCE_DIR}/src/ui/qml"
              "$<TARGET_FILE:QtCalendarApp>"
      COMMENT "Running windeployqt for QtCalendarApp"
      VERBATIM
    )
  else()
    message(WARNING "windeployqt not found: runtime DLLs will not be copied automatically.")
  endif()
endif()

