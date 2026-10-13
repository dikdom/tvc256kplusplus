#include "tvc-fatfs.h"
#include "tvc-fatfs-pendrive.h"

FRESULT tvc_fatfs_pendrive_open_file() {
    return tvc_fatfs_open_file(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_close_file() {
    return tvc_fatfs_close_file();
}

FRESULT tvc_fatfs_pendrive_read_file() {
    return tvc_fatfs_read_file();
}

FRESULT tvc_fatfs_pendrive_read_file_dest() {
    return tvc_fatfs_read_file_dest();
}

FRESULT tvc_fatfs_pendrive_write_file() {
    return tvc_fatfs_write_file();
}

FRESULT tvc_fatfs_pendrive_write_file_source() {
    return tvc_fatfs_write_file_source();
}

FRESULT tvc_fatfs_pendrive_open_dir() {
    return tvc_fatfs_open_dir(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_close_dir() {
    return tvc_fatfs_close_dir();
}

FRESULT tvc_fatfs_pendrive_read_dir() {
    return tvc_fatfs_read_dir();
}

FRESULT tvc_fatfs_pendrive_file_seek() {
    return tvc_fatfs_file_seek();
}

FRESULT tvc_fatfs_pendrive_getcwd() {
    return tvc_fatfs_getcwd(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_chdir() {
    return tvc_fatfs_chdir(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_mkdir() {
    return tvc_fatfs_mkdir(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_delete() {
    return tvc_fatfs_delete(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_rename() {
    return tvc_fatfs_rename(DRIVE_PENDRIVE);
}
FRESULT tvc_fatfs_pendrive_getstat() {
    return tvc_fatfs_getstat(DRIVE_PENDRIVE);
}

FRESULT tvc_fatfs_pendrive_sync() {
    return tvc_fatfs_sync();
}

FRESULT tvc_fatfs_pendrive_mount_dsk() {
    return tvc_fatfs_mount_dsk();
}

FRESULT tvc_fatfs_pendrive_unmount_dsk() {
    return tvc_fatfs_unmount_dsk();
}