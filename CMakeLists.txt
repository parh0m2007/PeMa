cmake_minimum_required(VERSION 3.21)

project(PeMa VERSION 1.0.0 LANGUAGES CXX)

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

qt_add_executable(PeMa
  src/app/main.cpp
  src/backend/WorkoutStore.cpp
  resources/resources.qrc
)

target_include_directories(PeMa PRIVATE src)

target_link_libraries(PeMa PRIVATE
  Qt6::Core
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::QuickControls2
  Qt6::Network
)

set_target_properties(PeMa PROPERTIES
  MACOSX_BUNDLE TRUE
)

if (WIN32)
  find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS
    "$ENV{QTDIR}/bin"
    "C:/Qt/6.10.2/msvc2022_64/bin"
    "C:/Qt/6.8.3/msvc2022_64/bin"
  )

  if (WINDEPLOYQT_EXECUTABLE)
    add_custom_command(TARGET PeMa POST_BUILD
      COMMAND "${WINDEPLOYQT_EXECUTABLE}"
              --no-translations
              --qmldir "${CMAKE_SOURCE_DIR}/src/ui/qml"
              "$<TARGET_FILE:PeMa>"
      COMMENT "Running windeployqt for PeMa"
      VERBATIM
    )
  else()
    message(WARNING "windeployqt not found: runtime DLLs will not be copied automatically.")
  endif()
endif()

