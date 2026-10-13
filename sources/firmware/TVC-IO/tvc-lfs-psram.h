#ifndef __TVC_LFS_PSRAM_H__
#define __TVC_LFS_PSRAM_H__

#include "lfs.h"

#define BLOCK_SIZE_PSRAM       4096   
#define READ_SIZE_PSRAM        256    
#define PROGRAM_SIZE_PSRAM     256    
#define LOOKAHEAD_SIZE_PSRAM   16     


int psram_drive_init();
uint8_t tvc_lfs_psram_file_open();
uint8_t tvc_lfs_psram_file_close();
uint8_t tvc_lfs_psram_file_read();
uint8_t tvc_lfs_psram_file_write();
uint8_t tvc_lfs_psram_dir_open();
uint8_t tvc_lfs_psram_dir_close();
uint8_t tvc_lfs_psram_dir_read();
uint8_t tvc_lfs_psram_file_seek();
uint8_t tvc_lfs_psram_chdir();
uint8_t tvc_lfs_psram_getcwd();
uint8_t tvc_lfs_psram_mkdir();
uint8_t tvc_lfs_psram_delete();
uint8_t tvc_lfs_psram_file_read_dest();
uint8_t tvc_lfs_psram_file_write_source();
uint8_t tvc_lfs_psram_getstat();
uint8_t tvc_lfs_psram_rename();
uint8_t tvc_lfs_psram_sync();
uint8_t tvc_lfs_psram_mount_dsk();
uint8_t tvc_lfs_psram_unmount_dsk();


#endif // __TVC_LFS_PSRAM_H__