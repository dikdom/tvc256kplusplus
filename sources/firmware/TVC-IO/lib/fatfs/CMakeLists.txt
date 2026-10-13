set(lib_name fatfs)
add_library(${lib_name} INTERFACE)

set(dir ${CMAKE_CURRENT_LIST_DIR}/source)

target_sources(${lib_name} INTERFACE
    ${dir}/ff.c
    ${dir}/ffsystem.c
    ${dir}/ffunicode.c
    ${dir}/diskio_usb.c
)

target_link_libraries(${lib_name} INTERFACE
    pico_stdlib
    tinyusb_host
)

target_include_directories(${lib_name} INTERFACE ${dir})

# enable all warnings
target_compile_options(${lib_name} INTERFACE -Wall -Wextra)
