#include "pico/stdlib.h"
#include "tvc-lfs-psram.h"
#include "ff.h"
#include "string.h"
#include "ctype.h"
#include "tvc-usb.h"
#include <unistd.h>
#include "hardware/sync.h"
#include "tvc-lfs.h"
#include "psram.h"

extern volatile uint8_t *psram_array;
extern struct lfs_info info;
extern uint8_t registerPSRAMSize;
extern uint8_t TVC_ROM[];

bool psram_drive_initialized = false;
char working_dir_psram[256] = "/";
lfs_t lfs_psram;
uint32_t free_psram_start;

int psram_drive_read(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, void *buffer, lfs_size_t size) {
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
    
    uint32_t psram_offs = (block * c->block_size) + off;
    memcpy(buffer, (const void *)(psram_array) + psram_offs, size);
    return 0;
}

int psram_drive_prog(const struct lfs_config *c, lfs_block_t block, lfs_off_t off, const void *buffer, lfs_size_t size) {
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
    uint32_t psram_offs = (block * c->block_size) + off;
    memcpy((const void * )psram_array + psram_offs, buffer, size);
    // if(log_lfs) {
    //     usb_printf("done\n"); main_loop_task();
    // }
    return 0;
}

int psram_drive_erase(const struct lfs_config *c, lfs_block_t block) {
    uint32_t psram_offs = (block * c->block_size);
    
    memset((const void * )psram_array + psram_offs, 0xFF, c->block_size);
    return 0;
}

int psram_drive_sync(__unused const struct lfs_config *c) { 
    return 0; 
}

static uint8_t psram_drive_read_buf[READ_SIZE_PSRAM]           __attribute__((aligned(4)));
static uint8_t psram_drive_prog_buf[PROGRAM_SIZE_PSRAM]        __attribute__((aligned(4)));
static uint8_t psram_drive_lookahead_buf[LOOKAHEAD_SIZE_PSRAM] __attribute__((aligned(4)));

// Konfiguráció
struct lfs_config psram_drive_cfg = {
    .read  = psram_drive_read,
    .prog  = psram_drive_prog,
    .erase = psram_drive_erase,
    .sync  = psram_drive_sync,

    .read_buffer      = psram_drive_read_buf,
    .prog_buffer      = psram_drive_prog_buf,
    .lookahead_buffer = psram_drive_lookahead_buf,

    .read_size = READ_SIZE_PSRAM,
    .prog_size = PROGRAM_SIZE_PSRAM,
    .block_size = BLOCK_SIZE_PSRAM,
    .block_count = 8*1024*1024 / BLOCK_SIZE_PSRAM,
    .cache_size = 256,
    .lookahead_size = LOOKAHEAD_SIZE_PSRAM,
    .block_cycles = 500,
};

/**
 * Initializes the PSRAM drive and formats it if necessary
 * INPUT: num_of_blocks - number of blocks to be used for the PSRAM drive. Each block is 4KB
 */
int psram_drive_init(uint32_t num_of_blocks) {
    free_psram_start = 0x00000000;
    if(psram_drive_initialized) {
        lfs_unmount(&lfs_psram);
        psram_drive_initialized = false;
    }
    psram_drive_cfg.block_count = num_of_blocks;
    if(num_of_blocks * BLOCK_SIZE_PSRAM > registerPSRAMSize * 1024 * 1024) {
        return -1;
    }
    memset((const void * )psram_array, 0xff, num_of_blocks * BLOCK_SIZE_PSRAM);
    int res = lfs_format(&lfs_psram, &psram_drive_cfg);
    if(res>=0) {
        res = lfs_mount(&lfs_psram, &psram_drive_cfg);
        if(res>=0) {
            if((num_of_blocks * 4096) < (psram_size() * 1024 * 1024))
                free_psram_start = num_of_blocks * BLOCK_SIZE_PSRAM;
            else
                free_psram_start = 0x00ffffff;
        }
    }

    psram_drive_initialized = (res >= 0);
    TVC_ROM[0x1824] = (res >= 0);
    return res;
}

uint8_t tvc_lfs_psram_file_open() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_file_open(&lfs_psram, true, working_dir_psram);
}

uint8_t tvc_lfs_psram_file_close() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_close(&lfs_psram);
}

uint8_t tvc_lfs_psram_file_read() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_read(&lfs_psram);
}

// extern uint8_t registerUSBDebug;
uint8_t tvc_lfs_psram_file_write() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_write(&lfs_psram);

}

/**
 * Opens a directory for listing
 * IN:
 *   0x1900/1     - Length of path to be listed
 *   0x1901/<len> - path
 * OUT:
 *   0x1a00/4     - directory handle
 */
uint8_t tvc_lfs_psram_dir_open() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_dir_open(&lfs_psram, working_dir_psram);
    }

/**
 * Closes an open directory
 * IN:
 *   0x1900/4     - directory handle
 * OUT:
 */
uint8_t tvc_lfs_psram_dir_close() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_dir_close(&lfs_psram);

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
uint8_t tvc_lfs_psram_dir_read() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_dir_read(&lfs_psram);

}

uint8_t tvc_lfs_psram_file_seek() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_file_seek(&lfs_psram);
}

uint8_t tvc_lfs_psram_file_read_dest() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_file_read_dest(&lfs_psram);
}

uint8_t tvc_lfs_psram_file_write_source() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_file_write_source(&lfs_psram);
}

uint8_t tvc_lfs_psram_getcwd() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_getcwd(working_dir_psram);
}

uint8_t tvc_lfs_psram_chdir() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_chdir(&lfs_psram, working_dir_psram);
}

uint8_t tvc_lfs_psram_mkdir() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_mkdir(&lfs_psram, working_dir_psram);
}

uint8_t tvc_lfs_psram_delete() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_delete(&lfs_psram, working_dir_psram);
}

uint8_t tvc_lfs_psram_getstat() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }

    return tvc_lfs_getstat(&lfs_psram, working_dir_psram);
}

uint8_t tvc_lfs_psram_sync() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_sync(&lfs_psram);
}

uint8_t tvc_lfs_psram_rename() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return LFS_ERR_READONLY_FS;
}

uint8_t tvc_lfs_psram_mount_dsk() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_mount_dsk(&lfs_psram, 2);
}

uint8_t tvc_lfs_psram_unmount_dsk() {
    if(!psram_drive_initialized) {
        return FR_NOT_READY;
    }
    return tvc_lfs_unmount_dsk();
}