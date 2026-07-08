set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(TARGET whisper-server)
add_executable(${TARGET} server.cpp httplib.h)

include(DefaultTargetOptions)

target_link_libraries(${TARGET} PRIVATE common json_cpp whisper ${CMAKE_THREAD_LIBS_INIT})

if (WIN32)
    target_link_libraries(${TARGET} PRIVATE ws2_32)
endif()

install(TARGETS ${TARGET} RUNTIME)

# WebSocket streaming server
set(TARGET_WS whisper-websocket-stream)
add_executable(${TARGET_WS} websocket-stream.cpp)

target_link_libraries(${TARGET_WS} PRIVATE common json_cpp whisper ${CMAKE_THREAD_LIBS_INIT})

if (WIN32)
    target_link_libraries(${TARGET_WS} PRIVATE ws2_32)
else()
    target_link_libraries(${TARGET_WS} PRIVATE pthread)
endif()

install(TARGETS ${TARGET_WS} RUNTIME)
