
#ifndef __TVC_FATFS_PENDRIVE_H__
#define __TVC_FATFS_PENDRIVE_H__

#include "ff.h"

#define DRIVE_PENDRIVE 0

FRESULT tvc_fatfs_pendrive_open_file();
FRESULT tvc_fatfs_pendrive_close_file();
FRESULT tvc_fatfs_pendrive_read_file();
FRESULT tvc_fatfs_pendrive_read_file_dest();
FRESULT tvc_fatfs_pendrive_write_file();
FRESULT tvc_fatfs_pendrive_write_file_source();
FRESULT tvc_fatfs_pendrive_open_dir();
FRESULT tvc_fatfs_pendrive_close_dir();
FRESULT tvc_fatfs_pendrive_read_dir();
FRESULT tvc_fatfs_pendrive_file_seek();
FRESULT tvc_fatfs_pendrive_getcwd();
FRESULT tvc_fatfs_pendrive_chdir();
FRESULT tvc_fatfs_pendrive_mkdir();
FRESULT tvc_fatfs_pendrive_delete();

FRESULT tvc_fatfs_pendrive_rename();
FRESULT tvc_fatfs_pendrive_getstat();
FRESULT tvc_fatfs_pendrive_sync();

FRESULT tvc_fatfs_pendrive_mount_dsk();
FRESULT tvc_fatfs_pendrive_unmount_dsk();

#endif