# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Initialise pico_sdk from installed location
# (note this can come from environment, CMake cache etc)

# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.2.0)
set(toolchainVersion 14_2_Rel1)
set(picotoolVersion 2.2.0-a4)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD weact_studio_rp2350b_core CACHE STRING "Board type")

#target_compile_definitions(TVC-IO PRIVATE
#    PICO_STACK_SIZE=0x2000
#)


# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(TVC-IO C CXX ASM)

set(PICO_TINYUSB_PATH "${CMAKE_CURRENT_LIST_DIR}/lib/tinyusb-new" CACHE INTERNAL "")

set(LITTLEFS_SRC
    ${CMAKE_CURRENT_LIST_DIR}/lib/littlefs/lfs.c
    ${CMAKE_CURRENT_LIST_DIR}/lib/littlefs/lfs_util.c
)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

# Add executable. Default name is the project name, version 0.1

add_executable(TVC-IO 
                TVC-IO-main.c 
                TVC-IO-main-sys.c 
                TVC-IO-main-gfx.c 
                psram.c 
                tvc-graphics.c 
                usb_descriptors.c
                tvc-routines.c
                tvc-usb.c
                tvc-fatfs.c
                tvc-fatfs-pendrive.c
                tvc-fatfs-dskdrive.c
                tvc-sid.c
                tvc-sound.c
                zx7Compress.c
                tvc-lfs-flash.c
                tvc-lfs-psram.c
                tvc-lfs.c
                ${PICO_TINYUSB_PATH}/src/portable/raspberrypi/pio_usb/hcd_pio_usb.c
                ${LITTLEFS_SRC}

)

pico_set_program_name(TVC-IO "TVC-IO")
pico_set_program_version(TVC-IO "0.1")

add_subdirectory(lib/fatfs)
add_subdirectory(lib/pico-pio-usb)
add_subdirectory(lib/tinyusb-new/src)


# no_flash means the target is to run from RAM
# pico_set_binary_type(TVC-IO no_flash)
pico_set_binary_type(TVC-IO copy_to_ram)
# pico_set_binary_type(TVC-IO default)
#pico_ensure_load_map(TVC-IO)

target_compile_definitions(TVC-IO PRIVATE
    PICO_FLASH_SAFE_EXECUTE_PICO_SUPPORT_MULTICORE_LOCKOUT=0
)

# Generate PIO header
pico_generate_pio_header(TVC-IO ${CMAKE_CURRENT_LIST_DIR}/tvc-system.pio)
pico_generate_pio_header(TVC-IO ${CMAKE_CURRENT_LIST_DIR}/tvc-overlay.pio)
pico_generate_pio_header(TVC-IO ${CMAKE_CURRENT_LIST_DIR}/tvc-dbushandler.pio)

# Modify the below lines to enable/disable output over UART/USB
pico_enable_stdio_uart(TVC-IO 0)
pico_enable_stdio_usb(TVC-IO 0)


# --- External Z80 compile ---
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.bin
    COMMAND c:/apps/sjasm/sjasm ${CMAKE_SOURCE_DIR}/Z80/tvc-256k++.asm ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.bin
    DEPENDS 
        ${CMAKE_SOURCE_DIR}/Z80/tvc-256k++.asm 
        ${CMAKE_SOURCE_DIR}/Z80/tvc-init.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-tools.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-open.asm 
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-chario.asm 
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-blkio.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-close.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-verify.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-pwd.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-dir.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-mkdir.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-delete.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-rename.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-seek.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-getbase.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-func-mntdsk.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-cli-page0.asm
        ${CMAKE_SOURCE_DIR}/Z80/tvc-cli-page1.asm

    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/Z80/
    COMMENT "Assembling Z80 program"
)

# --- Binary embedding ---
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.o
#    COMMAND ${CMAKE_OBJCOPY} -I binary -O elf32-littlearm -B arm --rename-section .data=.rodata,alloc,readonly,load ${CMAKE_CURRENT_BINARY_DIR}/tvc_gcfw.bin ${CMAKE_CURRENT_BINARY_DIR}/tvc_gcfw.o
    COMMAND ${CMAKE_OBJCOPY} -I binary -O elf32-littlearm -B arm --rename-section .data=.flashdata --set-section-flags .flashdata=alloc,load,readonly tvc-256k++.bin ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.o
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.bin ${CMAKE_SOURCE_DIR}/Z80/tvc-256k++.asm
    COMMENT "Embedding Z80 binary into firmware"
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/c16-hungarian.o
    COMMAND ${CMAKE_OBJCOPY} -I binary -O elf32-littlearm -B arm --rename-section .data=.flashdata --set-section-flags .flashdata=alloc,load,readonly ../binaries/c16-hungarian.bin ${CMAKE_CURRENT_BINARY_DIR}/c16-hungarian.o
    DEPENDS ${CMAKE_CURRENT_LIST_DIR}/binaries/c16-hungarian.bin
    COMMENT "Embedding Hungarian C16 charset into firmware"
)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/tvc-16cimage.o
    COMMAND ${CMAKE_OBJCOPY} -I binary -O elf32-littlearm -B arm --rename-section .data=.flashdata --set-section-flags .flashdata=alloc,load,readonly ../binaries/tvc-16cimage.bmp ${CMAKE_CURRENT_BINARY_DIR}/tvc-16cimage.o
    DEPENDS ${CMAKE_CURRENT_LIST_DIR}/binaries/tvc-16cimage.bmp
    COMMENT "Embedding First 16c TVC image into firmware"
)

target_sources(TVC-IO PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/tvc-256k++.o)
target_sources(TVC-IO PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/c16-hungarian.o)
target_sources(TVC-IO PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/tvc-16cimage.o)


# Add the standard library to the build
target_link_libraries(TVC-IO
                        fatfs
                        tinyusb_host
                        tinyusb_device
                        pico_pio_usb
                        hardware_pio
                        hardware_dma
                        hardware_xip_cache
                        hardware_exception
                        hardware_pwm
                        hardware_flash
                        hardware_sync
                        pico_multicore
                        pico_stdlib
)

target_compile_definitions(TVC-IO PUBLIC 
            PIO_USB_USE_TINYUSB
            PICO_FLASH_ASSUME_CORE0_SAFE=1
            PICO_FLASH_ASSUME_CORE1_SAFE=1
            PICO_FLASH_SAFE_EXECUTE_PICO_SUPPORT_MULTICORE_LOCKOUT=0
            PRIVATE PICO_USE_SW_SPIN_LOCKS=0
            )


target_compile_options(TVC-IO PRIVATE -fno-builtin-memcpy)
target_compile_options(TVC-IO PRIVATE -fno-builtin-strcpy)
# target_compile_options(TVC-IO PRIVATE -save-temps=obj)

# Add the standard include files to the build
target_include_directories(TVC-IO PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_LIST_DIR}/lib/littlefs
)

# Add any user requested libraries
target_link_libraries(TVC-IO )

pico_add_extra_outputs(TVC-IO)

add_custom_command(TARGET TVC-IO POST_BUILD
    COMMAND arm-none-eabi-size ${CMAKE_CURRENT_BINARY_DIR}/TVC-IO.elf
    COMMENT "Generating size report for firmware"
)

# target_compile_definitions(TVC-IO PRIVATE
#     PICO_STACK_SIZE=0x1000       # Core 0 stack átállítása 4 KB-ra
#     PICO_CORE1_STACK_SIZE=0x1000 # Core 1 stack átállítása 4 KB-ra
# )