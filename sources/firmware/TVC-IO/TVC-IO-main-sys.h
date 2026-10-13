#ifndef TVC_IO_CORE1_H
#define TVC_IO_CORE1_H

#include "pico/stdlib.h"

#define FW_VERSION_MAJOR 0
#define FW_VERSION_MINOR 24
/**
 * history
 * 0.01 - started the versioning.
 *  This version supports:
 *  - USB pendrive, mouse
 *  - saving mouse speed in flash
 *  - graphics: sprites, bitmap, text modes, scrolling, border color
 *  - TVC 256k++ routine execution
 *  - PSRAM mapping in/out
 *  - caching files into PSRAM
 * 0.02 - added PSRAM mapping, TVC 256k++ support
 * 0.03 - added delay for USB
 *        enchanced cd in flash (/p1/p2 is fixed)
 *        fixed clear bitmap to clear all the 32k instead of 8k only
 * 0.04 - set spinlocks instead of sw locks, delay removed
 *        PRIVATE PICO_USE_SW_SPIN_LOCKS=0 added to CMakeLists.txt
 * 0.05 - blinks at startup. NOT WORKING as cart init is not called
 * 0.06 - pseudo open-drain implemented for /PHANTOM
 * 0.07 - minor fixes in routines
 * 0.08 - minor fixes in routines
 *        added sprite mirror and zx7decode
 *        core voltage 1.2V
 * 0.09 - psram and flash drive: read dir returns read-only files (not regular file type)
 *      - spinlock/sw locks not used
 *      - added getstat routine for psram and flash drive, open dir for flash drive, mkdir for flash drive
 *      - fixed getstat in usb, being conform with psram and littlefs - returns the same structure as a direntry
 * 0.10 - added graphics primitives: get/set pen color, draw dot, line and rectangle (outline and filled)
 * 0.11 - added a NOP to the mem-access end timing (fix for PHANTOM release - pseudo open-drain)
 * 0.12 - fixed multiline, added ellipse primitives: draw and fill
 * 0.13 - fixed base addr post processing in main-sys.c file, after reg write
 *        copy image with transparent pixels implemented
 *        gfx coordinates are int16_t instead of uint16_t
 *        registerFunctionBitmapBaseAddr introduced, functions works on the selected 32kB bitmap block 
 * 0.14 - copy_image_block can copy from slow ram also
 *        functions works on the selected 32kB bitmap block from the full fastRAM
 *        multi routine execution implemented
 *        added getFunctionParamSize function to get the size of the function parameters
 * 0.15 - arrow-to-up and arrow-to-left characters can be printed with chars 'A'+29 and 'A'+30
 *        fix in load to dest function call's return value. Doesn't delete the 8th byte in in/out buffer
 * 0.16 - create_psram_drive, delete_psram_drive and get_first_usable_psram_pos functions added
 * 0.17 - core voltage increased to 1.25V from 1.20V
 *      - all usb_printf removed, no serial console initialized
 * 0.18 - loading and writing blocks are psram capable
 * 0.19 - .dsk mount added, IO ROM is pagable via a new REG_MEMORY_ROM_PAGE register.
 *        In CLI the DIR cmd accepts joker-like expressions: *.poststr, prestr* and filename
 * 0.20 - dsk, flash and psram drive validity in readonly registers
 *      - bugfix in CLI, fix reg increment restore on lcdsr
 *      - bugfix for zx7Decompress, out param right after inputs, paramlength fixed to 10 bytes
 *      - copy_dir_to_psram has a new parameter, enable/disable progress display
 *          output: updating the first byte of the input, # of loaded files (updated during load)
 *      - umdsk fixed, setting properly the $D825 ( TVC_ROM[1825] ) value
 *      - rectangle, fill_rectangle, fill_ellipse sped up with enhanced horizontal line
 * 0.21 - introducing the math expression evaluation
 * 0.22 - SQR added to the math expr eval
 * 0.23 - scanline_flood_fill is refactored to use the draw_horizontal_line_impl function, 
 *        which is faster than the set_dotc_impl (dot-by-dot) function
 *      - load" is not needed after launcher loaded something
 *      - added draw_filled_triangle function with 2x2 color fill, and if penColor is not 8, 
 *        the triangle is drawn with the penColor
 *      - added TYPE_VARREF type as a pointer to a variable, which is used in the math expression evaluation
 *      - added 2c fill_box
 *      - added 2c scan_fill
 *      - added copy memory blocks from fast/slow RAM to fast RAM with different increments
 * 0.24 - sprites struct is padded to 12 bytes, iterates a bit faster 
 *      - enabled and foreground flags are moved together in the struct (4. and 5. bytes)
 *      - SPRITE_xxx_LOW and _HIGH registers now calculated properly on single sprite xxx write (BUGFIX)
 *      - raising sprite-sprite or background-sprite IRQ doesn't stop the gfx screen (BUGFIX)
 *      - writing to above (BASE_PORT + 7) cannot cause a crash anymore (BUGFIX)
 *      - y scrolling without upper-lower borders now scrolls-in as empty (transparent) lines 
 *        instead of garbage (BUGFIX)
 *      - reading from or writing to a file from PSRAM now is boundary checked for the PSRAM size (BUGFIX)
 *      - sprite-background collision detection now doesn't overflow with 1 line (BUGFIX)
 *      - appending .cas postfix to a filename is now boundary checked for the 256 bytes buffer (BUGFIX)
 *      - closing a directory might not release the handle. Now it does (BUGFIX)
 *      - memory_move_to_slow now fixed - target and source was swapped (BUGFIX)
 *      - memory move, sprite mirror functions pre-execution limit checks fixed (BUGFIX)
 */


typedef struct {
    uint8_t id;
    uint8_t msgType;
    uint16_t address;
    uint8_t registerSelect;
    uint8_t data;       // Valid only for write operations
} message_t;

typedef enum {
    REG_SPRITE_X = 0x00,
    REG_SPRITE_Y = 0x20,
    REG_SPRITE_COLOR = 0x40,
    REG_SPRITE_PHASE = 0x50,
    REG_SPRITE_FOREGROUND = 0x60,
    REG_SPRITE_ENABLE = 0x70,
    REG_SPRITE_COLORMODE = 0x80,
    REG_SPRITE_ENABLE_LOW = 0x90,
    REG_SPRITE_ENABLE_HIGH,
    REG_SPRITE_FOREGROUND_LOW,
    REG_SPRITE_FOREGROUND_HIGH,
    REG_SPRITE_COLORMODE_LOW,
    REG_SPRITE_COLORMODE_HIGH,
    REG_SPRITE_SP_COLLISION_LOW,
    REG_SPRITE_SP_COLLISION_HIGH,
    REG_SPRITE_BG_COLLISION_LOW,
    REG_SPRITE_BG_COLLISION_HIGH,
    REG_SPRITE_SP_IRQMASK_LOW,
    REG_SPRITE_SP_IRQMASK_HIGH,
    REG_SPRITE_BG_IRQMASK_LOW,
    REG_SPRITE_BG_IRQMASK_HIGH,
    REG_SPRITE_BASE_ADDR,
    REG_SCREEN_VIDEOMODE = 0xA0,
    REG_SCREEN_SCREEN_BASE_ADDR,
    REG_SCREEN_SCREEN_COLOR_BASE_ADDR,
    REG_SCREEN_FONT_BASE_ADDR,
    REG_SCREEN_BITMAP_BASE_ADDR,
    REG_SCREEN_SCROLL_X,
    REG_SCREEN_SCROLL_Y,
    REG_SCREEN_BORDER_COLOR,
    REG_SCREEN_Y,
    REG_SCREEN_MAXY,
    REG_MEMORY_P2 = 0xB0,
    REG_MEMORY_P3,
    REG_MEMORY_MAP_8M_P2_LOW,
    REG_MEMORY_MAP_8M_P2_HIGH,
    REG_MEMORY_MAP_8M_P3_LOW,
    REG_MEMORY_MAP_8M_P3_HIGH,
    REG_MEMORY_PSRAM_SIZE_IN_MB,
    REG_MEMORY_ROM_PAGE,
    REG_FUNCTION_EXECUTE = 0xC0,
    REG_FUNCTION_PARAM_START,
    REG_FUNCTION_RESULT,
    REG_FW_VERSION_MAJOR,
    REG_FW_VERSION_MINOR,
    REG_DRIVE_SELECT,
    REG_FUNCTION_MULTI_EXECUTE,
    REG_FUNCTION_BITMAP_BASE,
    REG_DRIVE_PSRAM_VALID,
    REG_DRIVE_FLASH_VALID,
    REG_DRIVE_DSK_VALID,
    REG_USB_INIT = 0xD0,
    REG_USB_MOUSE_BUTTONS,
    REG_USB_MOUSE_DX,
    REG_USB_MOUSE_DY,
    REG_USB_MOUSE_DW,
    REG_USB_MOUSE_SPEED,
    REG_USB_MSC_CMD,
    REG_USB_DEBUG = 220,
    REG_VSID_BASE = 0xE0
} tvcpp_register_t;

typedef enum {
    MSC_FOPENFILE = 0x01,
    MSC_FCLOSEFILE,
    MSC_FREAD,
    MSC_FWRITE,
    MSC_FOPENDIR,
    MSC_FCLOSEDIR,
    MSC_FREADDIR,
    MSC_FWRITE_SRC,
    MSC_FREAD_DEST,
    MSC_FSEEK,
    MSC_FGETCWD,
    MSC_FCHDIR,
    MSC_FMKDIR,
    MSC_FDELETE,
    MSC_FRENAME,
    MSC_FSTAT,
    MSC_FSYNC,
    MSC_MOUNT_DSK,
    MSC_UMOUNT_DSK,
    MSC_CHDRIVE //nope
} msc_command_t;

bool processPSRAMMapping(void);
void main_system(void);
void preinit_core_sys();

// extern const unsigned char _binary_tvc_gcfw_bin_start[];
extern const unsigned char _binary_tvc_256k___bin_start[];//  __attribute__((section(".flashdata")));

// extern const unsigned char _binary_tvc_gcfw_bin_end[];
extern const unsigned char _binary_tvc_256k___bin_end[];//    __attribute__((section(".flashdata")));

#define z80_prog_bin _binary_tvc_256k___bin_start
#define z80_prog_len (_binary_tvc_256k___bin_end - _binary_tvc_256k___bin_start)

#endif // TVC_IO_CORE1_H
