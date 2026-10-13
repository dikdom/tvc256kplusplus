#include "pico/stdlib.h"
#include "hardware/flash.h"
#include "tvc-lfs-flash.h"
#include "ff.h"
#include "string.h"
#include "ctype.h"
#include "tvc-usb.h"
#include <unistd.h>
#include "hardware/sync.h"
#include "tvc-lfs.h"

extern uint8_t TVC_ROM[];
extern uint8_t TVC_RAM[];
char working_dir_flash[256] = "/";
// char temp_path[256];
bool log_lfs = false;
lfs_t lfs_flash;
bool flash_drive_initialized = false;

// Határozzuk meg a fájlrendszer helyét a Flash-ben (pl. 1MB-nál kezdődik)

// Függvények a LittleFS számára
int pico_read(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, void *buffer, lfs_size_t size) {
    // if(log_lfs) {
    //     usb_printf("pico_read: block: %d, off: %d, block addr: %p, size: %d, block_count: %d, block_size: %d ... ", 
    //                         block, off, buffer, size, c->block_count, c->block_size);
    //                         main_loop_task();
    // }
    if (block >= c->block_count) {
        return LFS_ERR_INVAL; // Megállítjuk a hívást, és hibát adunk vissza a LittleFS-nek
    }
    
    // 2. Ha az eltolás is érvénytelen lenne
    if (off >= c->block_size) {
        return LFS_ERR_INVAL;
    }

    uint32_t flash_offs = FLASH_TARGET_OFFSET + (block * c->block_size) + off;
    memcpy(buffer, (const uint8_t *)(XIP_NOCACHE_NOALLOC_BASE  + flash_offs), size);
    // if(log_lfs) {
    //     usb_printf("done\n"); main_loop_task();sleep_ms(100);
    // }
    return 0;
}

int pico_prog(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, const void *buffer, lfs_size_t size) {
    // if(log_lfs) {
    //     usb_printf("pico_read: block: %d, off: %d, block addr: %p, size: %d, block_count: %d, block_size: %d ... ", 
    //                         block, off, buffer, size, c->block_count, c->block_size);
    //                         main_loop_task();
    // }
    if (block >= c->block_count) {
        return LFS_ERR_INVAL; // Megállítjuk a hívást, és hibát adunk vissza a LittleFS-nek
    }
    
    // 2. Ha az eltolás is érvénytelen lenne
    if (off >= c->block_size) {
        return LFS_ERR_INVAL;
    }
    uint32_t flash_offs = FLASH_TARGET_OFFSET + (block * c->block_size) + off;
    flash_range_program(flash_offs, buffer, size);
    // if(log_lfs) {
    //     usb_printf("done\n"); main_loop_task();
    // }
    return 0;
}

int pico_erase(const struct lfs_config *c, lfs_block_t block) {
    uint32_t flash_offs = FLASH_TARGET_OFFSET + (block * c->block_size);
    flash_range_erase(flash_offs, c->block_size);
    return 0;
}

int pico_sync(__unused const struct lfs_config *c) { return 0; }

static uint8_t flash_drive_read_buf[256]        __attribute__((aligned(4)));
static uint8_t flash_drive_prog_buf[256]        __attribute__((aligned(4)));
static uint8_t flash_drive_lookahead_buf[16]    __attribute__((aligned(4)));

// Konfiguráció
struct lfs_config cfg = {
    .read  = pico_read,
    .prog  = pico_prog,
    .erase = pico_erase,
    .sync  = pico_sync,

    .read_buffer      = flash_drive_read_buf,
    .prog_buffer      = flash_drive_prog_buf,
    .lookahead_buffer = flash_drive_lookahead_buf,

    .read_size = 256,
    .prog_size = FLASH_PAGE_SIZE,     // 256 byte
    .block_size = FLASH_SECTOR_SIZE,  // 4096 byte
    .block_count = FS_SIZE / FLASH_SECTOR_SIZE,
    .cache_size = 256,
    .lookahead_size = 16,
    .block_cycles = 500,
};


void flash_drive_init() {
    flash_drive_initialized = (lfs_mount(&lfs_flash, &cfg) >= 0);
}

uint8_t tvc_lfs_flash_file_open() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_file_open(&lfs_flash, true, working_dir_flash);
}

uint8_t tvc_lfs_flash_file_close() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_close(&lfs_flash);
}

uint8_t tvc_lfs_flash_file_read() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_read(&lfs_flash);
}

// extern uint8_t registerUSBDebug;
uint8_t tvc_lfs_flash_file_write() {

    return FR_WRITE_PROTECTED; // Read-only filesystem, writing is not allowed
}

/**
 * Opens a directory for listing
 * IN:
 *   0x1900/1     - Length of path to be listed
 *   0x1901/<len> - path
 * OUT:
 *   0x1a00/4     - directory handle
 */
uint8_t tvc_lfs_flash_dir_open() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_dir_open(&lfs_flash, working_dir_flash);
}

/**
 * Closes an open directory
 * IN:
 *   0x1900/4     - directory handle
 * OUT:
 */
uint8_t tvc_lfs_flash_dir_close() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_dir_close(&lfs_flash);
}

/**
 * Reads a directory entry from an open directory
 * INPUT:
 *  0x1900/4   - a valid directory handle
 * OUTPUT:
 *  0x1a00/256 - a pascal type filename. This is "" if the 
 *               directory listing is finished
 *  0x1b00/1   - file type
 *  0x1b01/4   - file size. If file size is bigger than 2^32-1 then it is set to 2^32-1
 *  0x1b05/13  - short filename, pascal sytle. Set only if filanem is longer than 12 chars
 */
uint8_t tvc_lfs_flash_dir_read() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_dir_read(&lfs_flash);
}

uint8_t tvc_lfs_flash_file_seek() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_seek(&lfs_flash);
}

uint8_t tvc_lfs_flash_file_read_dest() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_file_read_dest(&lfs_flash);
}

uint8_t tvc_lfs_flash_getcwd() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_getcwd(working_dir_flash);
}

uint8_t tvc_lfs_flash_chdir() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_chdir(&lfs_flash, working_dir_flash);
}

uint8_t tvc_lfs_flash_mkdir() {
    return LFS_ERR_READONLY_FS;
}

uint8_t tvc_lfs_flash_delete() {
    return LFS_ERR_READONLY_FS;
}

uint8_t tvc_lfs_flash_getstat() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_getstat(&lfs_flash, working_dir_flash);
}

uint8_t tvc_lfs_flash_sync() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return 0;
}

uint8_t tvc_lfs_flash_rename() {
    return LFS_ERR_READONLY_FS;
}

uint8_t tvc_lfs_flash_file_write_source() {
    return LFS_ERR_READONLY_FS;
}

uint8_t tvc_lfs_flash_mount_dsk() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_mount_dsk(&lfs_flash, 3);
}

uint8_t tvc_lfs_flash_unmount_dsk() {
    if(!flash_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_unmount_dsk();
}