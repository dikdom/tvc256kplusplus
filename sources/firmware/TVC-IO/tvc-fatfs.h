#include "ff.h"
#include "lfs.h"

#ifndef __TVC_FS_H__
#define __TVC_FS_H__

FRESULT tvc_fatfs_open_file(uint8_t ld_num);
FRESULT tvc_fatfs_close_file();
FRESULT tvc_fatfs_read_file();
FRESULT tvc_fatfs_read_file_dest();
FRESULT tvc_fatfs_write_file();
FRESULT tvc_fatfs_write_file_source();
FRESULT tvc_fatfs_open_dir(uint8_t ld_num);
FRESULT tvc_fatfs_close_dir();
FRESULT tvc_fatfs_read_dir();
FRESULT tvc_fatfs_file_seek();
FRESULT tvc_fatfs_getcwd(uint8_t ld_num);
FRESULT tvc_fatfs_chdir(uint8_t ld_num);
FRESULT tvc_fatfs_mkdir(uint8_t ld_num);
FRESULT tvc_fatfs_delete(uint8_t ld_num);

FRESULT tvc_fatfs_rename(uint8_t ld_num);
FRESULT tvc_fatfs_getstat(uint8_t ld_num);
FRESULT tvc_fatfs_sync();

FRESULT tvc_fatfs_mount_dsk();
FRESULT tvc_fatfs_unmount_dsk();

#endif