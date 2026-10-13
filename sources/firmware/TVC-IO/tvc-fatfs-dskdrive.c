#include "tvc-fatfs.h"
#include "tvc-fatfs-dskdrive.h"

FRESULT tvc_fatfs_dskdrive_open_file() {
    return tvc_fatfs_open_file(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_close_file() {
    return tvc_fatfs_close_file();
}

FRESULT tvc_fatfs_dskdrive_read_file() {
    return tvc_fatfs_read_file();
}

FRESULT tvc_fatfs_dskdrive_read_file_dest() {
    return tvc_fatfs_read_file_dest();
}

FRESULT tvc_fatfs_dskdrive_write_file() {
    return tvc_fatfs_write_file();
}

FRESULT tvc_fatfs_dskdrive_write_file_source() {
    return tvc_fatfs_write_file_source();
}

FRESULT tvc_fatfs_dskdrive_open_dir() {
    return tvc_fatfs_open_dir(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_close_dir() {
    return tvc_fatfs_close_dir();
}

FRESULT tvc_fatfs_dskdrive_read_dir() {
    return tvc_fatfs_read_dir();
}

FRESULT tvc_fatfs_dskdrive_file_seek() {
    return tvc_fatfs_file_seek();
}

FRESULT tvc_fatfs_dskdrive_getcwd() {
    return tvc_fatfs_getcwd(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_chdir() {
    return tvc_fatfs_chdir(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_mkdir() {
    return tvc_fatfs_mkdir(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_delete() {
    return tvc_fatfs_delete(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_rename() {
    return tvc_fatfs_rename(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_getstat() {
    return tvc_fatfs_getstat(DRIVE_DSKDRIVE);
}

FRESULT tvc_fatfs_dskdrive_sync() {
    return tvc_fatfs_sync();
}

FRESULT tvc_fatfs_dskdrive_mount_dsk() {
    return tvc_fatfs_mount_dsk();
}

FRESULT tvc_fatfs_dskdrive_unmount_dsk() {
    return tvc_fatfs_unmount_dsk();
}