#ifndef __TVC_LFS_FLASH_H__
#define __TVC_LFS_FLASH_H__


#include "lfs.h"

#define FLASH_TARGET_OFFSET (1024 * 1024) 
#define FS_SIZE ( PICO_FLASH_SIZE_BYTES - FLASH_TARGET_OFFSET )

void flash_drive_init();
uint8_t tvc_lfs_flash_file_open();
uint8_t tvc_lfs_flash_file_close();
uint8_t tvc_lfs_flash_file_read();
uint8_t tvc_lfs_flash_file_write();
uint8_t tvc_lfs_flash_dir_open();
uint8_t tvc_lfs_flash_dir_close();
uint8_t tvc_lfs_flash_dir_read();
uint8_t tvc_lfs_flash_file_seek();
uint8_t tvc_lfs_flash_chdir();
uint8_t tvc_lfs_flash_getcwd();
uint8_t tvc_lfs_flash_mkdir();
uint8_t tvc_lfs_flash_delete();
uint8_t tvc_lfs_flash_rename();
uint8_t tvc_lfs_flash_file_read_dest();
uint8_t tvc_lfs_flash_file_write_source();
uint8_t tvc_lfs_flash_getstat();
uint8_t tvc_lfs_flash_sync();
uint8_t tvc_lfs_flash_mount_dsk();
uint8_t tvc_lfs_flash_unmount_dsk();

#endif // __TVC_LFS_FLASH_H__