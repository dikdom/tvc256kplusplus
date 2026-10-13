/*-----------------------------------------------------------------------*/
/* Low level disk I/O module SKELETON for FatFs     (C)ChaN, 2019        */
/*-----------------------------------------------------------------------*/
/* If a working storage control module is available, it should be        */
/* attached to the FatFs via a glue function rather than modifying it.   */
/* This is an example of glue functions to attach various exsisting      */
/* storage control modules to the FatFs module with a defined API.       */
/*-----------------------------------------------------------------------*/
/* 
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Ha Thach (tinyusb.org) (for original example code)
 * Copyright (c) 2022 rppicomidi (for porting to FatFs 14b and Pico-USB-PIO project)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * This diskio implementation assumes that all calls to the FatFs API are made from
 * RP2040 core 0 and the MSC USB host stack is running on core 1. Otherwise, the
 * API needs some mechanism to block until the USB transfers between the USB drive
 * and the RP2040 complete (e.g., an RTOS or manually task calls in a loop)
 */

#include "tusb_config.h"
#include "ff.h"			/* Obtains integer types */
#include "diskio_usb.h"		/* Declarations of disk functions */
#include "tusb.h"
#include "lfs.h"
// #include "pico/mutex.h"

#define DRIVE_DSK CFG_TUH_DEVICE_MAX
#define DSK_SECTOR_SIZE 512
// int usb_printf(const char *fmt, ...);
#if CFG_TUH_MSC

static DSTATUS disk_state[CFG_TUH_DEVICE_MAX];
// static mutex_t msc_fat_mutex;

static msc_fat_xfer_status_t msc_fat_status;
/*-----------------------------------------------------------------------*/
/* MSC plug status functions                                             */
/*-----------------------------------------------------------------------*/
static uint8_t pdrv_to_daddr_map[FF_VOLUMES];
static uint8_t available_pdrv_bitmap;

/**
 * @brief convert the physical drive number to a USB device address
 *
 * @param pdrv the physical drive number 0-(FF_VOLUMES-1)
 * @return uint8_t the USB device address of the drive or 0 if pdrv is no present
 */
uint8_t msc_pdrv_to_daddr(uint8_t pdrv)
{
    return pdrv_to_daddr_map[pdrv];
}


/**
 * @brief convert a USB device address to a physical drive number
 *
 * @param daddr USB device address
 * @return uint8_t the physical drive number or FF_VOLUMES if daddr is not a drive
 */
uint8_t msc_daddr_to_pdrv(uint8_t daddr)
{
    uint8_t pdrv = FF_VOLUMES;
    for (size_t idx = 0; idx < sizeof(pdrv_to_daddr_map); idx++)
    {
        if (pdrv_to_daddr_map[idx] == daddr)
        {
            pdrv = idx;
            break;
        }
    }
    return pdrv;
}

uint8_t msc_map_next_pdrv(uint8_t daddr)
{
    uint8_t next_drive_plus_1 = __builtin_ffs(available_pdrv_bitmap);
    assert(next_drive_plus_1 != 0 && next_drive_plus_1 <= FF_VOLUMES);
    uint8_t pdrv = next_drive_plus_1 - 1;
    available_pdrv_bitmap &= ~(1 << pdrv); // clear the available drive bit
    pdrv_to_daddr_map[pdrv] = daddr;
    return pdrv;
}

uint8_t msc_unmap_pdrv(uint8_t daddr)
{
    assert(daddr <= FF_VOLUMES);
    uint8_t pdrv = msc_daddr_to_pdrv(daddr);
    if (pdrv < FF_VOLUMES)
    {
        available_pdrv_bitmap |= (1 << pdrv); // set the available drive bit
        pdrv_to_daddr_map[daddr] = 0;
    }
    return pdrv;
}

void msc_fat_unplug(
    BYTE pdrv /* Physical drive nmuber to identify the drive */
)
{
    if (pdrv < CFG_TUH_DEVICE_MAX)
        disk_state[pdrv] |= STA_NOINIT | STA_NODISK;
    ;
}

void msc_fat_plug_in(
    BYTE pdrv /* Physical drive nmuber to identify the drive */
)
{
    if (pdrv < CFG_TUH_DEVICE_MAX)
        disk_state[pdrv] &= ~STA_NODISK;
}

bool msc_fat_is_plugged_in(
    BYTE pdrv /* Physical drive nmuber to identify the drive */
)
{
    bool plugged_in = false;
    if (pdrv < CFG_TUH_DEVICE_MAX)
    {
        plugged_in = (disk_state[pdrv] & STA_NODISK) == 0;
    }
    return plugged_in;
}

void msc_fat_init()
{
    // mutex_init(&msc_fat_mutex);
    msc_fat_status = MSC_FAT_ERROR;
    for (int pdrv = 0; pdrv < CFG_TUH_DEVICE_MAX; pdrv++)
        msc_fat_unplug(pdrv); // assume no drives are plugged int
    available_pdrv_bitmap = (1 << FF_VOLUMES) - 1;
    memset(pdrv_to_daddr_map, 0, sizeof(pdrv_to_daddr_map));
}

void msc_fat_set_status(msc_fat_xfer_status_t stat)
{
    // mutex_enter_blocking(&msc_fat_mutex);
    msc_fat_status = stat;
    // mutex_exit(&msc_fat_mutex);
}

msc_fat_xfer_status_t msc_fat_get_xfer_status()
{
    // mutex_enter_blocking(&msc_fat_mutex);
    msc_fat_xfer_status_t res = msc_fat_status;
    // mutex_exit(&msc_fat_mutex);
    return res;
}

void msc_fat_wait_transfer_complete()
{
    while (msc_fat_get_xfer_status() == MSC_FAT_IN_PROGRESS)
    {
        main_loop_task();
    }
}

bool msc_fat_complete_cb(uint8_t dev_addr, tuh_msc_complete_data_t const* cb_data)
{
    // TODO does the msc_fat_status have to be address dependent?
    (void)dev_addr;
    if (cb_data->csw->status == MSC_CSW_STATUS_PASSED)
    {
        msc_fat_set_status(MSC_FAT_COMPLETE);
    }
    else
    {
        msc_fat_set_status(MSC_FAT_ERROR);
    }
    return cb_data->csw->status == MSC_CSW_STATUS_PASSED;
}

/*-----------------------------------------------------------------------*/
/* Get Drive Status                                                      */
/*-----------------------------------------------------------------------*/

extern uint8_t dsk_file_type;
extern FIL dsk_file_usb;
extern lfs_file_t dsk_file_lfs;
extern lfs_t *dsk_lfs_fs;

DSTATUS disk_status(
    BYTE pdrv /* Physical drive nmuber to identify the drive */
)
{
    if (pdrv == DRIVE_DSK) {
        return dsk_file_type ? 0 : STA_NOINIT | STA_NODISK;
    } else  {
        if (pdrv >= CFG_TUH_DEVICE_MAX)
            return STA_NOINIT | STA_NODISK;
        return disk_state[pdrv];
    }
}

/*-----------------------------------------------------------------------*/
/* Inidialize a Drive                                                    */
/*-----------------------------------------------------------------------*/


DSTATUS disk_initialize(
    BYTE pdrv /* Physical drive nmuber to identify the drive */
)
{
    DSTATUS stat = STA_NOINIT;
    if(pdrv == DRIVE_DSK) {
        if(dsk_file_type)
            stat = 0;
        else
            stat = STA_NODISK;
    } else if (pdrv < CFG_TUH_DEVICE_MAX) {
        if ((disk_state[pdrv] & STA_NODISK) == 0)
        {
            disk_state[pdrv] = 0;
            stat = 0;
            msc_fat_set_status(MSC_FAT_COMPLETE);
        }
    }
    // usb_printf("diskio: stat %02x, pdrv: %d\n", stat, pdrv);sleep_ms(50);
    return stat;
}

/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

DRESULT disk_read(
    BYTE pdrv,    /* Physical drive nmuber to identify the drive */
    BYTE *buff,   /* Data buffer to store read data */
    LBA_t sector, /* Start sector in LBA */
    UINT count    /* Number of sectors to read */
)
{
    DRESULT device_res = RES_PARERR;
    FRESULT function_res;
    if(pdrv == DRIVE_DSK) {

        switch(dsk_file_type) {
            case 0:
                return RES_NOTRDY;
            case 1: // USB drive mounted as .dsk file
                UINT bytes_read;
                FSIZE_t offset = (FSIZE_t)sector * DSK_SECTOR_SIZE;
                // usb_printf("diskio: offset $%06x, pdrv: %d\n", offset, pdrv);sleep_ms(50);
                // Pozicionálás a .dsk fájlban
                if ((function_res= f_lseek(&dsk_file_usb, offset)) != FR_OK) {
                    // usb_printf("diskio: seek failed, %d\n", res);sleep_ms(50);
                    return RES_ERROR;
                }

                // Szektor(ok) beolvasása
                if ((function_res = f_read(&dsk_file_usb, buff, count * DSK_SECTOR_SIZE, &bytes_read)) != FR_OK) {
                    // usb_printf("diskio: read failed, %d\n", res);sleep_ms(50);
                    return RES_ERROR;
                }

                if (bytes_read != count * DSK_SECTOR_SIZE) {
                    return RES_ERROR; // Fájl vége, vagy hiba
                }

                return RES_OK;
            case 2:
            case 3:
                offset = (FSIZE_t)sector * DSK_SECTOR_SIZE;
                if (lfs_file_seek(dsk_lfs_fs, &dsk_file_lfs, offset, LFS_SEEK_SET) < 0) {
                    return RES_ERROR;
                }

                if ((bytes_read = lfs_file_read(dsk_lfs_fs, &dsk_file_lfs, buff, count * DSK_SECTOR_SIZE)) < 0) {
                    return RES_ERROR;
                }

                if (bytes_read != count * DSK_SECTOR_SIZE) {
                    return RES_ERROR; // Fájl vége, vagy hiba
                }

                return RES_OK;
            default:
                return RES_NOTRDY;
        }

    } else if (pdrv < CFG_TUH_DEVICE_MAX && buff != NULL) {
        if (disk_state[pdrv] & (STA_NODISK | STA_NOINIT))
        {
            device_res = RES_NOTRDY;
        }
        else
        {
            assert(msc_fat_get_xfer_status() == MSC_FAT_COMPLETE);
            uint8_t dev_addr = msc_pdrv_to_daddr(pdrv);
            msc_fat_set_status(MSC_FAT_IN_PROGRESS);
            if (!tuh_msc_read10(dev_addr, 0, buff, sector, count, msc_fat_complete_cb, 0))
            {
                device_res = RES_ERROR;
            }
            else
            {
                msc_fat_wait_transfer_complete();
                if (msc_fat_get_xfer_status() == MSC_FAT_ERROR)
                {
                    device_res = RES_ERROR;
                }
                else
                {
                    device_res = RES_OK;
                }
            }
        }
    }
    return device_res;
}

/*-----------------------------------------------------------------------*/
/* Write Sector(s)                                                       */
/*-----------------------------------------------------------------------*/

#if FF_FS_READONLY == 0

DRESULT disk_write(
    BYTE pdrv,        /* Physical drive nmuber to identify the drive */
    const BYTE *buff, /* Data to be written */
    LBA_t sector,     /* Start sector in LBA */
    UINT count        /* Number of sectors to write */
)
{
    DRESULT res = RES_PARERR;
    if(pdrv == DRIVE_DSK) {
        switch(dsk_file_type) {
            case 0:
                return RES_NOTRDY;
            case 1: // USB drive mounted as .dsk file
                UINT bytes_written;
                FSIZE_t offset = (FSIZE_t)sector * DSK_SECTOR_SIZE;

                if (f_lseek(&dsk_file_usb, offset) != FR_OK) {
                    return RES_ERROR;
                }

                if (f_write(&dsk_file_usb, buff, count * DSK_SECTOR_SIZE, &bytes_written) != FR_OK) {
                    return RES_ERROR;
                }

                if (bytes_written != count * DSK_SECTOR_SIZE) {
                    return RES_ERROR;
                }
                return RES_OK;
            case 2:
            case 3:
                offset = (FSIZE_t)sector * DSK_SECTOR_SIZE;
                if (lfs_file_seek(dsk_lfs_fs, &dsk_file_lfs, offset, LFS_SEEK_SET) < 0) {
                    return RES_ERROR;
                }

                if ((bytes_written = lfs_file_write(dsk_lfs_fs, &dsk_file_lfs, buff, count * DSK_SECTOR_SIZE)) < 0) {
                    return RES_ERROR;
                }

                if (bytes_written != count * DSK_SECTOR_SIZE) {
                    return RES_ERROR; // Fájl vége, vagy hiba
                }

                return RES_OK;
            default:
                return RES_NOTRDY;
        }
    } else if (pdrv < CFG_TUH_DEVICE_MAX && buff != NULL) {
        if (disk_state[pdrv] & (STA_NODISK | STA_NOINIT))
        {
            res = RES_NOTRDY;
        }
        else
        {
            assert(msc_fat_get_xfer_status() == MSC_FAT_COMPLETE);
            uint8_t dev_addr = msc_pdrv_to_daddr(pdrv);
            msc_fat_set_status(MSC_FAT_IN_PROGRESS);
            if (!tuh_msc_write10(dev_addr, 0, buff, sector, count, msc_fat_complete_cb, 0))
            {
                res = RES_ERROR;
            }
            else
            {
                msc_fat_wait_transfer_complete();
                if (msc_fat_get_xfer_status() == MSC_FAT_ERROR)
                {
                    res = RES_ERROR;
                }
                else
                {
                    res = RES_OK;
                }
            }
        }
    }
    return res;
}

#endif

/*-----------------------------------------------------------------------*/
/* Miscellaneous Functions                                               */
/*-----------------------------------------------------------------------*/

DRESULT disk_ioctl(
    BYTE pdrv, /* Physical drive nmuber (0..) */
    BYTE cmd,  /* Control code */
    void *buff /* Buffer to send/receive control data */
)
{
    (void)buff;
    (void)pdrv;
    DRESULT res = RES_OK;

    if(pdrv == DRIVE_DSK) {
        if (!dsk_file_type) 
            return RES_NOTRDY;

        switch (cmd) {
            case CTRL_SYNC:
                switch(dsk_file_type) {
                    case 1: // USB drive mounted as .dsk file
                        if (f_sync(&dsk_file_usb) == FR_OK) 
                            return RES_OK;
                        break;
                    case 2:
                    case 3:
                        if(lfs_file_sync(dsk_lfs_fs, &dsk_file_lfs) >= 0)
                            return RES_OK;
                        break;
                }
                return RES_ERROR;

            case GET_SECTOR_SIZE:
                *(WORD*)buff = DSK_SECTOR_SIZE;
                return RES_OK;

            case GET_SECTOR_COUNT:
                switch(dsk_file_type) {
                    case 1: // USB drive mounted as .dsk file
                        // A virtuális lemez mérete: fájlméret / szektorméret
                        *(LBA_t*)buff = f_size(&dsk_file_usb) / DSK_SECTOR_SIZE;
                        return RES_OK;
                        break;
                    case 2:
                    case 3:
                        lfs_soff_t size = lfs_file_size(dsk_lfs_fs, &dsk_file_lfs) / DSK_SECTOR_SIZE;
                        if(size>=0) {
                            *(lfs_soff_t *)buff = size;
                            return RES_OK;
                        } else {
                            return RES_ERROR;
                        }
                        break;
                }
                break;
            case GET_BLOCK_SIZE:
                *(DWORD*)buff = 1;
                return RES_OK;
                break;
            default:
                return RES_PARERR;
        }
    } else if (disk_state[pdrv] != 0)
    {
        res = RES_ERROR; // not mounted
    }
    else
    {
        switch (cmd)
        {
        case CTRL_SYNC:
            break;
        case GET_SECTOR_COUNT:
        {
            LBA_t *ptr = (LBA_t *)buff;
            *ptr = tuh_msc_get_block_count(pdrv + 1, 0);
        }
        break;
        case GET_SECTOR_SIZE:
        {
            WORD *ptr = (WORD *)buff;
            *ptr = tuh_msc_get_block_size(pdrv + 1, 0);
        }
        break;
        case GET_BLOCK_SIZE:
        {
            DWORD *ptr = (DWORD *)buff;
            *ptr = 1; // unknown
        }
        break;
        default:
            res = RES_ERROR;
            break;
        }
    }
    return res;
}

#endif