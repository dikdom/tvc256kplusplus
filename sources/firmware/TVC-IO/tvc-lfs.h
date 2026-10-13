#ifndef __TVC_LFS_H__
#define __TVC_LFS_H__

#include "lfs.h"

#define LFS_ERR_READONLY_FS 40
#define LFS_ERR_END_OF_FILE 41

uint8_t tvc_lfs_file_open(lfs_t *lfs, bool readOnly, char *working_dir);
uint8_t tvc_lfs_file_close(lfs_t *lfs);
uint8_t tvc_lfs_file_read(lfs_t *lfs);
uint8_t tvc_lfs_file_write(lfs_t *lfs);
uint8_t tvc_lfs_dir_open(lfs_t *lfs, char* working_dir);
uint8_t tvc_lfs_dir_close(lfs_t *lfs);
uint8_t tvc_lfs_dir_read(lfs_t *lfs);
uint8_t tvc_lfs_file_seek(lfs_t *lfs);
uint8_t tvc_lfs_file_read_dest(lfs_t *lfs);
uint8_t tvc_lfs_file_write_source(lfs_t *lfs);
uint8_t tvc_lfs_getcwd(char *working_dir);
uint8_t tvc_lfs_chdir(lfs_t *lfs, char *working_dir);
uint8_t tvc_lfs_rename(lfs_t *lfs, char *working_dir);
uint8_t tvc_lfs_mkdir(lfs_t *lfs, char *working_dir);
uint8_t tvc_lfs_delete(lfs_t *lfs, char *working_dir);
uint8_t tvc_lfs_getstat(lfs_t *lfs, char *working_dir);
uint8_t tvc_lfs_sync(lfs_t *lfs);
uint8_t tvc_lfs_mount_dsk(lfs_t *lfs, uint8_t dsk_target_file_type);
uint8_t tvc_lfs_unmount_dsk();

#endif