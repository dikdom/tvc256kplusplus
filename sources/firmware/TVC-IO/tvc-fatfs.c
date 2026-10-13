#include "tvc-fatfs.h"
#include "ff.h"
#include "tvc-usb.h"
#include "pico/stdlib.h"
#include "TVC-IO-main-sys.h"
#include <string.h>
#include "tusb.h"
#include "psram.h"

FIL fileHandles[4];
DIR dirHandles[4];
bool availableFileHandles[4] = {true, true, true, true};
bool availableDirHandles[4] = {true, true, true, true};

FATFS dsk_fat_fs;
FIL dsk_file_usb;
// char drive_select[] = "0:";
uint8_t dsk_file_type = 0;

extern uint8_t TVC_ROM[];
extern uint8_t TVC_RAM[];
extern uint8_t *psram_array;
void str_tolower(char *str);

FIL *getFreeFileHandle() {
    for (int i = 0; i < 4; i++) {
        if (availableFileHandles[i]) {
            availableFileHandles[i] = false;
            return &fileHandles[i];
        }
    }
    return NULL; // No available file handles
}

DIR *getFreeDirHandle() {
    for (int i = 0; i < 4; i++) {
        if (availableDirHandles[i]) {
            availableDirHandles[i] = false;
            return &dirHandles[i];
        }
    }
    return NULL; // No available dir handles
}

void __attribute__((noinline)) releaseFileHandle(FIL *handle) {
    for (int i = 0; i < 4; i++) {
        if (&fileHandles[i] == handle) {
            availableFileHandles[i] = true;
            return;
        }
    }
}

void __attribute__((noinline)) releaseDirHandle(DIR *handle) {
    for (int i = 0; i < 4; i++) {
        if (&dirHandles[i] == handle) {
            availableDirHandles[i] = true;
            return;
        }
    }
}

bool isFileHandleValid(FIL *handle) {
    bool result = false;
    for (int i = 0; (i < 4) && (!result) ; i++) {
        result |= (&fileHandles[i] == handle);
    }
    return result;
}

bool isDirHandleValid(DIR *handle) {
    bool result = false;
    for (int i = 0; (i < 4) && (!result) ; i++) {
        result = result || (&dirHandles[i] == handle);
    }
    return result;
}

const char *cas_suffix = ".cas";
bool ends_with_cas(char *fileName) {
    if(!fileName)
        return false;
    size_t fileNameLength = strlen(fileName);
    if(fileNameLength<4)
        return false;
    
    return strcasecmp(fileName + fileNameLength - 4, cas_suffix) == 0;
}
uint8_t activeDrive = 0;

void set_active_drive(uint8_t ld_num) {
    if(activeDrive != ld_num) {
        char path[3] = {ld_num + '0', ':', '\0'};
        FRESULT res;
        if((res = f_chdrive(path)) == FR_OK) {
            activeDrive = ld_num;
            // usb_printf("Changed active drive to %d\n", ld_num);
        } 
    }
    // usb_printf("Active drive is %d\n", activeDrive);
}

/**
 * Opens a file, either for read or for write
 * IN: 
 *   0x1900/1 : openMode (check https://elm-chan.org/fsw/ff/doc/open.html for modes)
 *   0x1901/1 : file type in case of creating/open for write
 *   0x1902/1 : file name length
 *   0x1903/1 : file name characters
 *     for reading
 *        if empty filename is provided, the first .cas file is searched in the current directory.
 *        if file doesn't exists and no extension is given, then tries to open <fileName>.cas file also
 *        Checks the first byte in file, must be 0x01 or 0x11
 *        seeks to 0x80, skipping cas header
 *        in case of cas file, the reported file size is decremented with the header size (0x80)
 *     for writing
 *        no empty filename is allowed
 *        if no extension given, .cas is added
 *        if .cas is the extension of the filename, then a dummy header is written
 * OUT:
 *   0x1a00/4 : fileHandle
 *   0x1a04/4 : fileSize (in case of open, otherwise 0x000000)
 *   0x1a08/- : len of filename selected
 *   0x1a09/- : characters of filename, 0x00 at the end
 */
 FRESULT tvc_fatfs_open_file(uint8_t ld_num) {
    FRESULT res;
    uint8_t openMode = TVC_ROM[0x1900];
    uint8_t fileType = TVC_ROM[0x1901];
    uint8_t len = TVC_ROM[0x1902];
    
    TVC_ROM[0x1903 + len] = 0x00; // Null-terminate the string
     
    if(openMode & ~(FA_READ | FA_WRITE | FA_OPEN_ALWAYS | FA_CREATE_ALWAYS | FA_CREATE_NEW | FA_OPEN_EXISTING | FA_OPEN_APPEND)) {
        return FR_INVALID_PARAMETER; // Invalid open mode
    }

    set_active_drive(ld_num);
    char fNameBuf[256]; 
    fNameBuf[0] = 0;
    uint64_t fileSize = 0;
    bool casFile = false;
    FILINFO fileInfo;
    // usb_printf("tvc-fs> openMode: %02x, fileType: %02x, len: %d, fName: %s\n", openMode, fileType, len, &TVC_ROM[0x1903]);

    if(openMode & FA_READ) {
        // OPEN FOR READ
        if(len == 0) {  // no filename was provided, let's find the first .cas file
            DIR *dirHandle = getFreeDirHandle();
            FRESULT res = f_opendir(dirHandle, "./");
            if(res != FR_OK) {
                releaseDirHandle(dirHandle);
                return FR_NO_FILE;
            }
                
            while((res=f_readdir(dirHandle, &fileInfo)) == FR_OK) {
                if(fileInfo.fname[0] == 0) {
                    f_closedir(dirHandle);
                    releaseDirHandle(dirHandle);
                    return FR_NO_FILE;
                }
                if((fileInfo.altname[0]!=0) && ends_with_cas(fileInfo.altname)) {
                    strcpy(fNameBuf, fileInfo.altname);
                    
                    // strcpy(fNameBuf, fileInfo.altname);
                    fileSize = fileInfo.fsize;
                    casFile = true;
                    break;
                } else if(ends_with_cas(fileInfo.fname)) {
                    // strcpy(fNameBuf, drive_select);
                    strcpy(fNameBuf, fileInfo.fname);

                    // strcpy(fNameBuf, fileInfo.fname);
                    fileSize = fileInfo.fsize;
                    casFile = true;
                    break;
                }
            }
            f_closedir(dirHandle);
            releaseDirHandle(dirHandle);
        } else {
            // there is fileName. 
            strcpy(fNameBuf, (char *)&TVC_ROM[0x1903]);
            if((len>1) && (fNameBuf[len-1]=='*')) {
                fNameBuf[len-1] = 0;
                str_tolower(fNameBuf);
                DIR *dirHandle = getFreeDirHandle();
                FRESULT res = f_opendir(dirHandle, "./");
                if(res != FR_OK) {
                    releaseDirHandle(dirHandle);
                    return FR_NO_FILE;
                }
                while((res=f_readdir(dirHandle, &fileInfo)) == FR_OK) {
                    if(fileInfo.fname[0] == 0) {
                        f_closedir(dirHandle);
                        releaseDirHandle(dirHandle);
                        return FR_NO_FILE;
                    }
                    str_tolower(fileInfo.fname);
                    // usb_printf("tvc-fs> checking file: %s vs %s\n", fileInfo.fname, fNameBuf);

                    if(((fileInfo.fattrib & AM_DIR)==0) && (strstr(fileInfo.fname, fNameBuf) == fileInfo.fname)) {
                        // strcpy(fNameBuf, drive_select);
                        strcpy(fNameBuf, fileInfo.fname);

                        // strncpy(fNameBuf, fileInfo.fname, 255);
                        fNameBuf[255] = 0;
                        break;
                    }
                }
                f_closedir(dirHandle);
                releaseDirHandle(dirHandle);
            }

            res = f_stat(fNameBuf, &fileInfo);
            // usb_printf("stat result1: %d for %s\n", res, fNameBuf);
            if(((res!=FR_OK) || (fileInfo.fattrib & AM_DIR)) && (strlen(fNameBuf)<252)) {
                // maybe it doesn't ends with .cas, let's check that also
                strcat(fNameBuf, ".cas");
                res = f_stat(fNameBuf, &fileInfo);
                // usb_printf("stat result2: %d for %s\n", res, fNameBuf);
                // usb_printf("stat result: %d for %s\n", res, fNameBuf);
                if(res==FR_OK) {
                    casFile = true;
                } else {
                    return res;
                }
            } else if(ends_with_cas(fNameBuf)) {
                casFile = true;
            }
            if(res == FR_OK) {
                fileSize = fileInfo.fsize;
            } else {
                return res;
            }
        }
    } else {
        // OPEN FOR WRITE
        if(len == 0)
            return FR_INVALID_NAME;

        if((fileType!=0x01) && (fileType!=0x11))
            return FR_INVALID_PARAMETER;

        if(TVC_ROM[0x1904] == ':')
            return FR_INVALID_PARAMETER;

        // strcpy(fNameBuf, drive_select);
        strcpy(fNameBuf, (const char *)&TVC_ROM[0x1903]);
        
        if(((!ends_with_cas(fNameBuf)) && ((len<4) || (fNameBuf[len-4] != '.'))) && (strlen(fNameBuf)<252)) {
            strcat(fNameBuf, ".cas");
        }

        // usb_printf("tvc-fatfs: open for write, fn: %s\n", fNameBuf);sleep_ms(50);
        casFile = ends_with_cas(fNameBuf);
    }

    FIL *fileHandle = getFreeFileHandle();
    if(fileHandle == NULL) {
        return FR_TOO_MANY_OPEN_FILES; // No available file handles
    }

    // usb_printf("tvc-fatfs, open: fn: %s\n", fNameBuf);sleep_ms(50);
    res = f_open(fileHandle, fNameBuf, openMode);
    if (res == FR_OK) {
        if(casFile) {
            if(openMode & FA_READ) {
                uint8_t caseMode;
                UINT br = 0;
                res = f_read(fileHandle, &caseMode, 1, &br);
                if((caseMode != 0x01) && (caseMode != 0x11)) {
                    // invalid CAS
                    f_close(fileHandle);
                    releaseFileHandle(fileHandle);
                    return 21;  // invalid CAS file, no proper first byte
                } else {
                    f_lseek(fileHandle, 0x80);
                    fileSize -= 0x80;
                }
            } else if(openMode & (FA_CREATE_NEW | FA_CREATE_ALWAYS)) {
                uint8_t byteToWrite = fileType;
                UINT bw;
                res = f_write(fileHandle, &byteToWrite, 1, &bw);
                byteToWrite = 0x00;
                for(int i=1; (res == FR_OK) && (i<128); i++)
                    res = f_write(fileHandle, &byteToWrite, 1, &bw);
                if(res == FR_OK)
                    res = f_sync(fileHandle);
                
                // usb_printf("of6: %p\n", &TVC_ROM[0x1000]);
            }
        }
        // usb_printf("handle: %08x, len: %d, fileName: %s\n", (uint32_t)fileHandle, strlen(fNameBuf), fNameBuf);
        // usb_printf("of7: %p\n", &TVC_ROM[0x1000]);
        // TVC_ROM[0x1a0e] = 0x75;

        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)fileHandle; // Store the file handle pointer
        *(uint32_t *)&TVC_ROM[0x1a04] = (uint32_t)fileSize;
        TVC_ROM[0x1a08] = (uint8_t) strlen(fNameBuf);
        strncpy((char *)&TVC_ROM[0x1a09], fNameBuf, 255);
        TVC_ROM[0x1b08] = 0;
        // for(int i=0; i < 9 + strlen(fNameBuf); i++) {
        //     usb_printf("%02x ", TVC_ROM[0x1a00 + i]);
        // }
        // usb_printf("\nof9: %p\n", &TVC_ROM[0x1000]);
    } else {
        releaseFileHandle(fileHandle); // Release the handle if open failed
        // usb_printf("not ok\n");
    }
    // usb_printf("tvc-usb: open result: %d\n", res);
    return res;
}

FRESULT tvc_fatfs_close_file() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("close_file: handle: %p\n", fileHandle);
    FRESULT res;
    if(fileHandle == NULL) {
        for(int i=0; i<4; i++) {
            f_close(&fileHandles[i]);
            availableFileHandles[i] = true;
        }
        res = FR_OK;
    } else {
        if(!isFileHandleValid(fileHandle))
            return 20;
        
        res = f_close(fileHandle);
        releaseFileHandle(fileHandle);
        memset(fileHandle, 0, sizeof(FIL));
    }
    // usb_printf("close_file: res: %d\n", res);
    return res;
}

/**
 * Read data from an open file
 * IN:
 *   0x1900/4 - Filehandle, returned by OPEN
 *   0x1904/2 - length, bytes to read, max 6x256 - 2
 * OUT:
 *   0x1a00/2 - num of read bytes
 *   0x1a02/  - read data ( num-of-read-bytes bytes)
 */
FRESULT tvc_fatfs_read_file() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);

    if(!isFileHandleValid(fileHandle))
        return 20;

    void *bufferAddr = (void *)&TVC_ROM[0x1a02];
    uint16_t bytesToRead = (*(uint16_t *)&TVC_ROM[0x1904]);
    if((bytesToRead == 0) || (bytesToRead > 6 * 256-2)) {
        return FR_INVALID_PARAMETER;
    }
    UINT bytesRead = 0;
    FRESULT res = f_read(fileHandle, bufferAddr, bytesToRead, &bytesRead);
    if(res == FR_OK)
        *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)bytesRead;
    return res;
}

FRESULT tvc_fatfs_read_file_dest() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);

    if(!isFileHandleValid(fileHandle))
        return 20;

    uint32_t bytesToRead = (*(uint32_t *)&TVC_ROM[0x1904]) & 0x00ffffff;
    uint32_t pos = *(uint32_t *)&TVC_ROM[0x1907] & 0x00ffffff;
    void *bufferAddr;
    if(pos & 0x800000) {
        // PSRAM address
        pos &= 0x7FFFFF;
        if(psram_size() < (pos + bytesToRead)) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&psram_array[pos];
    } else {
        if( (bytesToRead == 0) || ((bytesToRead + pos) > 256*1024) ) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&TVC_RAM[pos];
    }
    // usb_printf("tvc_read_file_dest: handle: %p, bytesToRead: %d, pos: %06x\n", fileHandle, bytesToRead, pos);main_loop_task();sleep_ms(50);
    UINT bytesRead = 0;
    FRESULT res = f_read(fileHandle, bufferAddr, bytesToRead, &bytesRead);
    if(res == FR_OK)
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)bytesRead;
    // usb_printf("tvc_read_file_dest: res: %d, bytesRead: %d\n", res, bytesRead);main_loop_task();sleep_ms(50);
    return res;
}

/**
 * Write bytes to file from TVC_ROM[0x1906]
 * IN:
 *   0x1900/4   - Filehandle, returned by OPEN
 *   0x1904/2   - length, bytes to write, must not be 0 and must be less than or equal to 6x 256 bytes
 *   0x1906/len - data to be writen
 * OUT:
 *   0x1a00/2 - num of written bytes
 */

FRESULT tvc_fatfs_write_file() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);
    if(!isFileHandleValid(fileHandle))
        return 20;

    uint16_t bytesToWrite = *(uint16_t *)&TVC_ROM[0x1904];
    void *buffer = (void *)&TVC_ROM[0x1906];
    if((bytesToWrite == 0) || (((uint32_t)bytesToWrite + 0x1906)>0x2000)){
        return FR_INVALID_PARAMETER;
    }
    // usb_printf("write_file: handle: %p, bytesToWrite: %d, b1: %02x\n", fileHandle, bytesToWrite, ((uint8_t *)buffer)[0]);
    UINT bytesWritten = 0;
    FRESULT res = f_write(fileHandle, (const void *)buffer, bytesToWrite, &bytesWritten);
    *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)bytesWritten;
    // usb_printf("write_file: res: %d, bytesWritten: %d\n", res, bytesWritten);
    return res;
}

/**
 * Write bytes to file from fast extRAM
 * IN:
 *   0x1900/4 - Filehandle, returned by OPEN
 *   0x1904/3 - length, bytes to write
 *   0x1907/3 - start index of bytes in full fast extRAM
 * OUT:
 *   0x1a00/3 - num of written bytes
 */
FRESULT tvc_fatfs_write_file_source() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);
    if(!isFileHandleValid(fileHandle))
        return 20;

    uint32_t bytesToWrite = *(uint32_t *)&TVC_ROM[0x1904] & 0x00ffffff;
    uint32_t startAddr = *(uint32_t *)&TVC_ROM[0x1907] & 0x00ffffff;
    void *bufferAddr;
    if(startAddr & 0x800000) {
        // PSRAM address
        startAddr &= 0x7FFFFF;
        if(psram_size() < (startAddr + bytesToWrite)) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&psram_array[startAddr];
    } else {
        if((bytesToWrite == 0) || (bytesToWrite + startAddr > 256*1024)) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&TVC_RAM[startAddr];
    }
    UINT bytesWritten = 0;
    FRESULT res = f_write(fileHandle, (const void *)bufferAddr, bytesToWrite, &bytesWritten);
    *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)bytesWritten;
    return res;
}

/**
 * Opens a directory for listing
 * IN:
 *   0x1900/1     - Length of path to be listed
 *   0x1901/<len> - path
 * OUT:
 *   0x1a00/4     - directory handle
 */
FRESULT tvc_fatfs_open_dir(uint8_t ld_num) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string

    DIR *dirHandle = getFreeDirHandle();
    if(dirHandle == NULL) {
        return FR_TOO_MANY_OPEN_FILES; // No available dir handles
    }

    set_active_drive(ld_num);
    uint8_t buffer[256];
    strcpy((char *)buffer, (char *)&TVC_ROM[0x1901]);

    FRESULT res = f_opendir(dirHandle, (const char *)buffer);
    if (res == FR_OK) {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)dirHandle; // Store the dir handle pointer
    } else {
        releaseDirHandle(dirHandle); // Release the handle if open failed
    }
    // usb_printf("opendir: res: %d\r\n", res);sleep_ms(50);
    return res;
}

/**
 * Closes an open directory
 * IN:
 *   0x1900/4     - directory handle
 * OUT:
 */
FRESULT tvc_fatfs_close_dir() {
    DIR *dirHandle = (DIR *) (*(uint32_t *)&TVC_ROM[0x1900]);
    if(!isDirHandleValid(dirHandle))
        return 20;
    
    FRESULT res = f_closedir(dirHandle);
    releaseDirHandle(dirHandle);
    memset(dirHandle, 0, sizeof(DIR));
    // usb_printf("closedir: res: %d\r\n", res);
    return res;
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
FRESULT tvc_fatfs_read_dir() {
    DIR *dirHandle =  (DIR *) (*(uint32_t *)&TVC_ROM[0x1900]);
    if(!isDirHandleValid(dirHandle))
        return 20;

    FILINFO *fileInfo = (FILINFO *)&TVC_ROM[0x1c00];
    
    memset(fileInfo, 0, sizeof(FILINFO));
    
    FRESULT res = f_readdir(dirHandle, fileInfo);
    if(res == FR_OK) {
        int len = strlen(fileInfo->fname);
        TVC_ROM[0x1a00] = (uint8_t)len;
        if(len!=0)
            memcpy(&TVC_ROM[0x1a01], fileInfo->fname, len);
        *(uint8_t *)&TVC_ROM[0x1b00] = fileInfo->fattrib;
        if(fileInfo->fsize>0xffffffff)
            *(uint32_t *)&TVC_ROM[0x1b01] = (uint32_t)0xffffffff;
        else
            *(uint32_t *)&TVC_ROM[0x1b01] = (uint32_t)fileInfo->fsize;

        if(len>12) {
            int alt_len = strlen(fileInfo->altname);
            memcpy(&TVC_ROM[0x1b06], fileInfo->altname, alt_len);
            TVC_ROM[0x1b05] = (uint8_t)alt_len;
            // usb_printf("alt_len: %d, altname: %s\r\n", 
            //     alt_len, 
            //     fileInfo->altname);
        }
        // usb_printf("len: %d, fname: %s, attr: %02x, size: %d\r\n", 
        //         len, 
        //         fileInfo->fname, 
        //         fileInfo->fattrib, 
        //         fileInfo->fsize);
    }
    // usb_printf("readdir: res: %d\r\n", res);

    return res;
}

FRESULT tvc_fatfs_file_seek() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);
    uint32_t pos = *(uint32_t *)&TVC_ROM[0x1904];
    if(!isFileHandleValid(fileHandle))
        return 20;
    return f_lseek(fileHandle, pos);
}

/**
 * Returns the current working directory
 * IN:
 *     -
 * OUT:
 *   0x1A00/1     - Length of name of directory
 *   0x1A01/<len> - Name of directory
 */

FRESULT tvc_fatfs_getcwd(uint8_t ld_num) {
    set_active_drive(ld_num);
    TCHAR *buffer = (TCHAR *)&TVC_ROM[0x1a01];
    FRESULT res = f_getcwd(buffer, (UINT)255);
    if(res==FR_OK) {
        int len;
        if((buffer[0] != 0) && (buffer[1] == ':')) {
            len = strlen(buffer+2);
            memmove(buffer, buffer+2, len);
        } else {
            len = strlen(buffer);
        }
        
        TVC_ROM[0x1a00] = (uint8_t)len;
    }
    return res;
}

/**
 * Change current working directory
 * IN:
 *   0x1900/1     - Length of name of directory
 *   0x1901/<len> - Name of directory
 * OUT:
 */
FRESULT tvc_fatfs_chdir(uint8_t ld_num) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0)
        return FR_INVALID_PARAMETER;
    
    if(TVC_ROM[0x1901] == ':') {
        return FR_INVALID_PARAMETER;
    }

    set_active_drive(ld_num);

    // drive_select[0] = ld_num + '0';

    TVC_ROM[0x1901 + len] = 0x00;
    char *fPathBuf = (char *)&TVC_ROM[0x1901];


    if((len>1) && (fPathBuf[len-1]=='*')) {
        FILINFO fileInfo;
        fPathBuf[len-1] = 0;
        str_tolower(fPathBuf);
        DIR *dirHandle = getFreeDirHandle();
        FRESULT res = f_opendir(dirHandle, "./");
        if(res != FR_OK) {
            releaseDirHandle(dirHandle);
            return FR_NO_PATH;
        }
        while((res=f_readdir(dirHandle, &fileInfo)) == FR_OK) {
            if(fileInfo.fname[0] == 0) {
                f_closedir(dirHandle);
                releaseDirHandle(dirHandle);
                return FR_NO_PATH;
            }
            str_tolower(fileInfo.fname);

            if(((fileInfo.fattrib & AM_DIR)!=0) && (strstr(fileInfo.fname, fPathBuf) == fileInfo.fname)) {
                strncpy(fPathBuf, fileInfo.fname, 255);
                fPathBuf[255] = 0;
                break;
            }
        }
        f_closedir(dirHandle);
        releaseDirHandle(dirHandle);
        if(res!=FR_OK) {
            return FR_NO_PATH;
        }
    }
    // if(fPathBuf[1] == ':') {
    //     memmove(fPathBuf, fPathBuf+2, len);
    //     memcpy(fPathBuf, drive_select, 2);
    // }

    return f_chdir(fPathBuf);
}


/**
 * Creates a new directory
 * IN:
 *   0x1900/1     - Length of name of directory
 *   0x1901/<len> - Name of directory
 * OUT:
 */
FRESULT tvc_fatfs_mkdir(uint8_t ld_num) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0)
        return FR_INVALID_PARAMETER;

    set_active_drive(ld_num);
    TVC_ROM[0x1901 + len] = 0x00;
    char dirNameBuf[256];

    strcpy(dirNameBuf, (char *)&TVC_ROM[0x1901]);

    uint8_t res = f_mkdir(dirNameBuf);
    return res;
}

/**
 * Deletes an empty directory or a file
 * IN:
 *   0x1900/1     - Length of name of file/directory
 *   0x1901/<len> - Name of file/directory
 * OUT:
 */
FRESULT tvc_fatfs_delete(uint8_t ld_num) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0)
        return FR_INVALID_PARAMETER;

    set_active_drive(ld_num);
    TVC_ROM[0x1901 + len] = 0x00;

    char fNameBuf[256];

    strcpy(fNameBuf, (char *)&TVC_ROM[0x1901]);

    return f_unlink(fNameBuf);
}

/**
 * Renames a file or directory
 * IN:
 *   0x1900/1           - Length of name of file or directory renaming FROM
 *   0x1901/<len1>      - Name of file or directory renaming FROM
 *   0x1901+len1/1      - Length of name of file or directory renaming TO
 *   0x1902+len1/<len2> - Name of directory renaming TO
 * OUT:
 */
FRESULT tvc_fatfs_rename(uint8_t ld_num) {
    uint8_t len1 = TVC_ROM[0x1900];
    uint8_t len2 = TVC_ROM[0x1901 + len1];
    if((len1 == 0) || (len2 == 0)) {
        return FR_INVALID_PARAMETER;
    }

    set_active_drive(ld_num);

    char fName1[256];
    char fName2[256];

    set_active_drive(ld_num);

    memcpy(fName1, &TVC_ROM[0x1901], len1);
    fName1[len1] = 0;
    memcpy(fName2, &TVC_ROM[0x1902 + len1], len2);
    fName2[len2] = 0;

    return f_rename(fName1, fName2);
}

/**
 * Returns the stat of the file
 * IN:
 *   0x1900/1     - Length of name of file/directory
 *   0x1901/<len> - Name of file/directory
 * OUT:
 *   0x1a00 - full DIRENTRY structure, including fname, attribs, size and altname
 *   0x1a00/256 - tvc string of the file/dir name
 *   0x1b00 - file attributes
 *   0x1b01/4 - file size, if bigger than 2^32-1 then it is set to 2^32-1
 *   0x1b05/13 - short filename, pascal sytle. Set only if filanem is longer than 12 chars
 */
FRESULT tvc_fatfs_getstat(uint8_t ld_num) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0)
        return FR_INVALID_PARAMETER;
    
    set_active_drive(ld_num);
    TVC_ROM[0x1901 + len] = 0x00;
    FILINFO fileInfo;
    char fNameBuf[256];
    strcpy(fNameBuf, (char *)&TVC_ROM[0x1901]);
    FRESULT res = f_stat((TCHAR *)fNameBuf, &fileInfo);
    if(res == FR_OK) {
        TVC_ROM[0x1a00] = (uint8_t)strlen(fileInfo.fname);
        memcpy(&TVC_ROM[0x1a01], fileInfo.fname, strlen(fileInfo.fname));
        TVC_ROM[0x1b00] = fileInfo.fattrib;
        *(uint32_t*)&TVC_ROM[0x1b01] = fileInfo.fsize<=0xffffffffl ? (uint32_t)fileInfo.fsize : 0xffffffff;
        if(strlen(fileInfo.fname)>12) {
            TVC_ROM[0x1b05] = (uint8_t)strlen(fileInfo.altname);
            memcpy(&TVC_ROM[0x1b06], fileInfo.altname, strlen(fileInfo.altname));
        } else {
            TVC_ROM[0x1b05] = 0;
        }
    }
    return res;
}

/**
 * Synchronizes an open file with the fs, empties buffers, etc...
 * IN:
 *  0x1900/4 - file handle
 * OUT:
 *  -
 */
FRESULT tvc_fatfs_sync() {
    FIL *fileHandle = (FIL *)( *(uint32_t *)&TVC_ROM[0x1900]);
    if(!isFileHandleValid(fileHandle))
        return 20;
    return f_sync(fileHandle);
}

/**
 * Mount a dsk file
 * IN:
 *  0x1900 File name
 * OUT:
 *  
 */

FRESULT tvc_fatfs_mount_dsk() {
    uint8_t len = TVC_ROM[0x1900];
    uint8_t fNameBuf[256];
    TVC_ROM[0x1901 + len] = 0;
    strcpy((char *)fNameBuf, (char *)&TVC_ROM[0x1901]);
    // usb_printf("mount: fName: %s\n", fNameBuf);sleep_ms(50);
    if(dsk_file_type != 0) {
        return FR_NOT_READY;
    }
    FRESULT fres = f_open(&dsk_file_usb, (TCHAR *)fNameBuf, FA_READ|FA_WRITE);
    dsk_file_type = (fres == FR_OK) ? 1 : 0;
    // usb_printf("mount: f_open res: %02x\n", fres);sleep_ms(50);
    if(fres == FR_OK) {
        fres = f_mount(&dsk_fat_fs, "1:", 1);
        // usb_printf("mount: f_mount res: %02x\n", fres);sleep_ms(50);
        if(fres != FR_OK) {
            f_close(&dsk_file_usb);
            dsk_file_type = 0;
            set_active_drive(0);
        }
    }

    TVC_ROM[0x1825] = (fres == FR_OK);

    // usb_printf("mount: fres: %02x\n", fres);sleep_ms(50);
    return fres;
}

FRESULT tvc_fatfs_unmount_dsk() {
    // usb_printf("tvc_fatfs_unmount_dsk: dsk_file_tye: %d\n", dsk_file_type);
    if(dsk_file_type == 1) {
        set_active_drive(0);
        f_unmount("1:");
        f_close(&dsk_file_usb);
        dsk_file_type = 0;

        if(TVC_ROM[0x1810] == 3) {
            TVC_ROM[0x1810] = 0;
        }
        TVC_ROM[0x1825] = 0;

        return FR_OK;
    } else {
        // usb_printf("tvc_fatfs_unmount_dsk: no dsk file mounted, or dsk file is not fatfs\n");
        return FR_INVALID_OBJECT;
    }
}
