
#ifndef __TVC_FATFS_DSKDRIVE_H__
#define __TVC_FATFS_DSKDRIVE_H__

#include "ff.h"

#define DRIVE_DSKDRIVE 1

FRESULT tvc_fatfs_dskdrive_open_file();
FRESULT tvc_fatfs_dskdrive_close_file();
FRESULT tvc_fatfs_dskdrive_read_file();
FRESULT tvc_fatfs_dskdrive_read_file_dest();
FRESULT tvc_fatfs_dskdrive_write_file();
FRESULT tvc_fatfs_dskdrive_write_file_source();
FRESULT tvc_fatfs_dskdrive_open_dir();
FRESULT tvc_fatfs_dskdrive_close_dir();
FRESULT tvc_fatfs_dskdrive_read_dir();
FRESULT tvc_fatfs_dskdrive_file_seek();
FRESULT tvc_fatfs_dskdrive_getcwd();
FRESULT tvc_fatfs_dskdrive_chdir();
FRESULT tvc_fatfs_dskdrive_mkdir();
FRESULT tvc_fatfs_dskdrive_delete();

FRESULT tvc_fatfs_dskdrive_rename();
FRESULT tvc_fatfs_dskdrive_getstat();
FRESULT tvc_fatfs_dskdrive_sync();

#endif