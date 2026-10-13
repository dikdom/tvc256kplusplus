#include "tvc-lfs.h"
#include "ff.h"
#include "string.h"
#include "ctype.h"
#include "tvc-usb.h"
#include <unistd.h>
#include "lfs.h"
#include "psram.h"

extern uint8_t TVC_ROM[];
extern uint8_t TVC_RAM[];
extern uint8_t *psram_array;

lfs_file_t lfs_file[4]; // Legfeljebb 4 fájl egyidejű megnyitásához
bool lfs_file_in_use[4] = {false, false, false, false};
lfs_dir_t lfs_dir_handle;
lfs_dir_t lfs_dir[4]; // Legfeljebb 4 könyvtár egyidejű megnyitásához
bool lfs_dir_in_use[4] = {false, false, false, false};
struct lfs_info info;
lfs_dir_t dir_handle;
char temp_path[256];

lfs_file_t *get_file_handle() {
    for(int i=0; i<4; i++) {
        if(!lfs_file_in_use[i]) {
            lfs_file_in_use[i] = true;
            return &lfs_file[i];
        }
    }
    return NULL; // Nincs szabad file handle
}

void release_file_handle(lfs_file_t *handle) {
    for(int i=0; i<4; i++) {
        if(&lfs_file[i] == handle) {
            lfs_file_in_use[i] = false;
            break;
        }
    }
}

lfs_dir_t *get_dir_handle() {
    for(int i=0; i<4; i++) {
        if(!lfs_dir_in_use[i]) {
            lfs_dir_in_use[i] = true;
            return &lfs_dir[i];
        }
    }
    return NULL; // Nincs szabad dir handle
}

void release_dir_handle(lfs_dir_t *handle) {
    for(int i=0; i<4; i++) {
        if(&lfs_dir[i] == handle) {
            lfs_dir_in_use[i] = false;
            break;
        }
    }
}

bool is_file_handle_valid(lfs_file_t *handle) {
    for(int i=0; i<4; i++) {
        if(&lfs_file[i] == handle) {
            return lfs_file_in_use[i];
        }
    }
    return false;
}

bool is_dir_handle_valid(lfs_dir_t *handle) {
    for(int i=0; i<4; i++)
        if(&lfs_dir[i] == handle) {
            return lfs_dir_in_use[i];
        }
    return false;
}

bool ends_with_cas(char *fileName);

void str_tolower(char *str) {
    for (int i = 0; str[i] && (i<256); i++) {
        str[i] = tolower((unsigned char)str[i]);
    }
}

uint8_t tvc_lfs_file_open(lfs_t *lfs, bool readOnly, char *working_dir) {
    
    uint8_t openMode = TVC_ROM[0x1900];
    uint8_t fileType = TVC_ROM[0x1901]; 
    uint8_t len = TVC_ROM[0x1902];

    if(readOnly && ((openMode & FA_READ) == 0))
        return LFS_ERR_READONLY_FS;
    
    TVC_ROM[0x1903 + len] = 0x00; // Null-terminate the string
    char *fileName = (char *)&TVC_ROM[0x1903];
    
    str_tolower(fileName);
    
    // for(int i=0; i<4; i++) {
    //     usb_printf("tvc_lfs_file_open: checking file handle %p, in use: %d\n", (void *)&file[i], file_in_use[i]);main_loop_task();sleep_ms(50);
    // }
    int flags = 0;
    if(openMode & FA_READ) flags |= LFS_O_RDONLY;
    if(openMode & FA_WRITE) flags |= LFS_O_WRONLY;
    if(openMode & FA_CREATE_ALWAYS) flags |= LFS_O_CREAT | LFS_O_TRUNC;
    else if(openMode & FA_CREATE_NEW) flags |= LFS_O_CREAT | LFS_O_EXCL;
    else if(openMode & FA_OPEN_ALWAYS) flags |= LFS_O_CREAT;
    else if(openMode & FA_OPEN_EXISTING) flags |= 0; // No additional flags needed

    // usb_printf("tvc_lfs_file_open: filename: %s, workingDir: %s, openMode: %d, type: %d, flags: %d\n", 
    //                               fileName, working_dir, openMode, fileType, flags);main_loop_task();sleep_ms(50);

    bool casFile = false;
    uint32_t fileSize = 0;
    if(len==0) {
        // No filename provided, find the first .cas file
        bool found = false;
        
        lfs_dir_open(lfs, &dir_handle, working_dir);
        while(lfs_dir_read(lfs, &dir_handle, &info) > 0) {
            if((info.type == LFS_TYPE_REG) && ends_with_cas(info.name)) {
                if((strlen(info.name) + strlen(working_dir)) >= 256) {
                    lfs_dir_close(lfs, &dir_handle);
                    // usb_printf("tvc_lfs_file_open: filename too long: %s\n", info.name);main_loop_task();sleep_ms(50);
                    return FR_INVALID_NAME; // Filename too long
                }
                // strcpy(temp_path, working_dir);
                // strcat(temp_path, info.name);
                strcpy(temp_path, working_dir);
                strcat(temp_path, info.name);
                strcpy(fileName, info.name);
                casFile = true;
                fileSize = info.size;
                found = true;
                break;
            }
        }
        lfs_dir_close(lfs, &dir_handle);
        if (!found) {
            // usb_printf("tvc_lfs_file_open: no .cas file found in directory: %s\n", working_dir);main_loop_task();sleep_ms(50);
            return FR_NO_FILE; // No .cas file found
        }
    } else {
        // Filename provided, use it directly

        if (fileName[0] == '/') {
            strcpy(temp_path, fileName);
            int i = len - 1;
            while((i>=0) && (temp_path[i] != '/')) {
                i--;
            }
            temp_path[i+1] = 0x00; // Remove filename from path, keep the directory
            memmove(fileName, &fileName[i+1], len - i); // Move filename to the start of fileName
            // usb_printf("tvc_lfs_file_open: absolute path provided, temp_path: %s, fileName: %s\n", temp_path, fileName);main_loop_task();sleep_ms(50);
        } else {
            // Relative path, prepend working directory
            strcpy(temp_path, working_dir);
        }

        if((strlen(fileName) + strlen(working_dir)) >= 252) {
            return FR_INVALID_NAME; // Filename too long
        }
        
        len = strlen(fileName);
        if((len>1) && (fileName[len-1] == '*')) {
            int res = 0;
            res = lfs_dir_open(lfs, &dir_handle, temp_path);
            // usb_printf("tvc_lfs_file_open: searching for file with prefix: %s in directory: %s, lfs_dir_open result: %d\n", fileName, temp_path, res);main_loop_task();sleep_ms(50);
            fileName[len-1] = 0;
            while((res = lfs_dir_read(lfs, &dir_handle, &info)) > 0) {
                if((info.type == LFS_TYPE_REG) && (strstr(info.name, fileName) == info.name)) {
                    // usb_printf("open: found, res: %d, fname: %s!", res, info.name);
                    strncpy(fileName, info.name, 255);
                    fileName[255] = 0;
                    break;
                }
            }
            lfs_dir_close(lfs, &dir_handle);
            if(res == 0) {
                return FR_NO_FILE;
            }
        }
        
        // strcpy(temp_path, working_dir);
        strcat(temp_path, fileName);

        // usb_printf("tvc_lfs_file_open: final path: %s\n", temp_path);main_loop_task();sleep_ms(50);
        
        if(ends_with_cas(fileName)) {
            uint8_t res = lfs_stat(lfs, temp_path, &info);
            if(res != 0) {  
                return res; // File not found
            }
            fileSize = info.size;
            casFile = true;
        } else if (strlen(temp_path) < 252) { // Ensure there's enough space to append ".cas"
            strcat(temp_path, ".cas");
            int res = lfs_stat(lfs, temp_path, &info);
            if(res < 0) {  
                temp_path[strlen(temp_path) - 4] = 0x00; // Remove .cas extension
                if(lfs_stat(lfs, temp_path, &info)>=0) {
                    fileSize = info.size;
                }
                casFile = false;
            } else {
                fileSize = info.size;
                casFile = true;
                strcat(fileName, ".cas");
            }
        }
    }

    lfs_file_t *fileHandle = get_file_handle();
    if(fileHandle == NULL) {
        return FR_TOO_MANY_OPEN_FILES; // No available file handles
    }
    // usb_printf("tvc_lfs_file_open: opening file with fileHandle: %p, path: %s, flags: %d\n", (void *)fileHandle, temp_path, flags);main_loop_task();sleep_ms(50);
    int res = lfs_file_open(lfs, fileHandle, temp_path, flags);
    // usb_printf("tvc_lfs_file_open: lfs_file_open result: %d\n", res);main_loop_task();sleep_ms(50);
    if(res == 0) {
        if(casFile) {
            lfs_file_read(lfs, fileHandle, &fileType, 1); // Read first byte to determine CAS type
            // usb_printf("tvc_lfs_file_open: CAS type byte read: %02x\n", fileType);main_loop_task();sleep_ms(50);
            if((fileType != 0x01) && (fileType != 0x11)) {
                lfs_file_close(lfs, fileHandle);
                return 21; // Invalid CAS file, no proper first byte
            } else {
                lfs_file_seek(lfs, fileHandle, 0x80, LFS_SEEK_SET); // Skip CAS header
                fileSize -= 0x80;
                // usb_printf("tvc_lfs_file_open: CAS header skipped, new fileSize: %d\n", fileSize);main_loop_task();sleep_ms(50);
            }
        }
    } else {
        release_file_handle(fileHandle);
        if(res == LFS_ERR_EXIST) {
            res = FR_EXIST; // Map to FatFS error code for "file already exists"
        }
    }
    *(uint32_t *)&TVC_ROM[0x1a00] = (res == 0) ? (uint32_t)(uintptr_t)fileHandle : 0x00; // Store file handle on success
    *(uint32_t *)&TVC_ROM[0x1a04] = (res == 0) ? fileSize : 0x00; // Store file size on success
    *(uint8_t *)&TVC_ROM[0x1a08]  = (res == 0) ? strlen(fileName) : 0x00; // Store filename length on success
    memcpy((void *)&TVC_ROM[0x1a09], 
           fileName, 
           (res == 0) ? TVC_ROM[0x1a08] + 1 : 0x00); // Store filename on success
    
    // usb_printf("tvc_lfs_fopen: res: %d, fileName: %s, fileHandle: %p, fileSize: %04x\n", res, fileName, fileHandle, fileSize);

    return (uint8_t)res;
}

uint8_t tvc_lfs_file_close(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *) (*(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_file_close: fileHandle: %p\n", (void *)fileHandle);main_loop_task();sleep_ms(100);
    uint8_t res;
    if(!is_file_handle_valid(fileHandle)) {
        return FR_INVALID_OBJECT; // Invalid file handle
    }
    res = lfs_file_close(lfs, fileHandle);

    release_file_handle(fileHandle);

    return res;
}


uint8_t tvc_lfs_file_read(lfs_t *lfs) {

    lfs_file_t *fileHandle = (lfs_file_t *)(*(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_file_read: fileHandle: %p\n", fileHandle);main_loop_task();sleep_ms(50);
    if(!is_file_handle_valid(fileHandle)) {
        return FR_INVALID_OBJECT; // Invalid file handle
    }
    void *buffer = (void *)&TVC_ROM[0x1a02];
    uint16_t bytesToRead = (*(uint16_t *)&TVC_ROM[0x1904]);
    // usb_printf("tvc_lfs_file_read: fileHandle: %p, bytesToRead: %04x\n", fileHandle, bytesToRead);main_loop_task();sleep_ms(50);
    if((bytesToRead == 0) || (bytesToRead > 6 * 256-2)) {
        return FR_INVALID_PARAMETER;
    }
    lfs_ssize_t bytesRead = lfs_file_read(lfs, fileHandle, buffer, bytesToRead);
    uint8_t res = 0;
    if(bytesRead > 0) {
        *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)bytesRead;
        res = 0;
    } else if(bytesRead == 0) {
        *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)0;
        res = LFS_ERR_END_OF_FILE;
    } else {
        *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)0;
        res = (uint8_t) bytesRead;
    }
    // usb_printf("tvc_lfs_file_read: res: %d, bytesRead: %04x\n", res, bytesRead);main_loop_task();
    return res;
}

uint8_t tvc_lfs_file_write(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *) (*(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_file_write: fileHandle: %p\n", (void *)fileHandle);main_loop_task();sleep_ms(50);
    if(fileHandle == NULL || !is_file_handle_valid(fileHandle)) {
        return FR_INVALID_OBJECT; // Invalid file handle
    }
    void *buffer = (void *)&TVC_ROM[0x1906];
    uint16_t bytesToWrite = (*(uint16_t *)&TVC_ROM[0x1904]);
    // usb_printf("tvc_lfs_file_write: bytesToWrite: %d\n", bytesToWrite);main_loop_task();sleep_ms(100);
    if((bytesToWrite == 0) || (bytesToWrite > 6 * 256 - 6)) {
        return FR_INVALID_PARAMETER;
    }
    lfs_ssize_t res = lfs_file_write(lfs, fileHandle, buffer, bytesToWrite);
    // usb_printf("tvc_lfs_file_write: bytesToWrite: %d, res: %d\n", bytesToWrite, res);main_loop_task();sleep_ms(100);
    if(res >= 0) {
        *(uint16_t *)&TVC_ROM[0x1a00] = (uint16_t)res;
        res = 0; // Success
        // usb_printf("tvc_lfs_file_write: write successful, bytes written: ");
        // for(int i=0; i<bytesToWrite; i++) {
        //     usb_printf("%02x ", TVC_ROM[0x1906 + i]);
        // }
        // usb_printf("\n");main_loop_task();sleep_ms(50);
    }
    return (uint8_t)res;
}

uint8_t tvc_lfs_dir_open(lfs_t *lfs, char* working_dir) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string
    lfs_dir_t *dirHandle = get_dir_handle();
    if(dirHandle == NULL) {
        return FR_TOO_MANY_OPEN_FILES; // No available directory handles
    }

    char *dirName = (char *)&TVC_ROM[0x1901];
    if(dirName[len-1] != '/')
        strcat(dirName, "/");
    
    if(strcmp(dirName, "./")==0)
        strcpy(dirName, working_dir);

    // usb_printf("lfs_dir_open: dir to open: %s\n", dirName);main_loop_task();sleep_ms(50);

    int res = lfs_dir_open(lfs, dirHandle, dirName);

    if (res == FR_OK) {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)dirHandle; // Store the dir handle pointer
    } else {
        release_dir_handle(dirHandle); // Release the handle if open failed
    }
    // usb_printf("tvc_lfs_dir_open: res: %d, handle: %p\n", res, res==0 ? (void *)dirHandle : NULL); main_loop_task();sleep_ms(50);
    return res;
}

uint8_t tvc_lfs_dir_close(lfs_t *lfs) {
    // usb_printf("tvc_lfs_dir_close: called\r\n"); main_loop_task();sleep_ms(50);
    lfs_dir_t *dirHandle = (lfs_dir_t *)(*(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_dir_close: handle: %p\r\n", (void *)dirHandle); main_loop_task();sleep_ms(50);
    if(!is_dir_handle_valid(dirHandle)) {
        return 20;
    }
    
    int res = lfs_dir_close(lfs, dirHandle);
    // usb_printf("tvc_lfs_dir_close: res: %d\r\n", res); main_loop_task();sleep_ms(50);
    
    release_dir_handle(dirHandle);

    return res<0 ? res : 0;
}

uint8_t tvc_lfs_dir_read(lfs_t *lfs) {
    lfs_dir_t *dirHandle = (lfs_dir_t *)(*(uint32_t *)&TVC_ROM[0x1900]);
    if(!is_dir_handle_valid(dirHandle)) {
        return 20;
    }
    struct lfs_info *info = (struct lfs_info *)&TVC_ROM[0x1c00];
    int res = 0;
    do {
        res = lfs_dir_read(lfs, dirHandle, info);
    } while(res>0 && ((strcmp(info->name, ".")==0) || (strcmp(info->name, "..")==0))); // Skip . and .. entry
    if(res > 0) {
        // usb_printf("lfs_dir_read: name: %s, size: %d, type: %d\r\n", info->name, info->size, info->type);   
        int len = strlen(info->name);
        TVC_ROM[0x1a00] = len;
        memcpy((void *)&TVC_ROM[0x1a01], info->name, len+1);
        TVC_ROM[0x1aff] = 0;
        TVC_ROM[0x1b00] = (info->type == LFS_TYPE_DIR) ? 0x10 : 0x01; // Store file type (directory or regular, readonly file)
        *(uint32_t *)&TVC_ROM[0x1b01] = (uint32_t)info->size;
        if(len>12) {
            int pos = len-1;
            while((pos>=0) && (info->name[pos]!='.')) 
                pos--;
            if(pos < len-4) {
                memcpy((void *)&TVC_ROM[0x1b06], info->name, 12); // Store short filename if no extension
            } else {
                memcpy((void *)&TVC_ROM[0x1b06], info->name, 7);
                TVC_ROM[0x1b06 + 7] = '~';
                TVC_ROM[0x1b06 + 8] = '.';
                memcpy((void *)&TVC_ROM[0x1b06 + 9], &info->name[pos+1], MIN(3, len-pos-1));
            }
            TVC_ROM[0x1b05] = 12;
        } else {
            TVC_ROM[0x1b05] = 0;
        }
        // usb_printf("readdir: name: %s, size: %d, type: %d\r\n", info->name, info->size, info->type);
        res = 0;
    } else if(res == 0) {
        TVC_ROM[0x1a00] = 0; // No more entries
    }
    return res;
}

uint8_t tvc_lfs_file_seek(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *)( *(uint32_t *)&TVC_ROM[0x1900]);
    uint32_t pos = *(uint32_t *)&TVC_ROM[0x1904];
    // usb_printf("tvc_lfs_seek: fHandle: %p, pos: %d\n", fileHandle, pos);
    if(!is_file_handle_valid(fileHandle))
        return 20;
    lfs_soff_t newPos = lfs_file_seek(lfs, (lfs_file_t *)fileHandle, pos, LFS_SEEK_SET);
    uint8_t res = 0;
    if(newPos == pos) {
        res = 0;
    } else {
        res = newPos;
    }

    // usb_printf("tvc_lfs_seek: newPos: %d, res: %d\n", newPos, res);

    return res;
}

uint8_t tvc_lfs_file_read_dest(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *)( *(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_file_read_dest: fileHandle: %p\n", fileHandle);main_loop_task();sleep_ms(50);

    if(!is_file_handle_valid(fileHandle))
        return 20;

    uint32_t bytesToRead = (*(uint32_t *)&TVC_ROM[0x1904]) & 0x00ffffff;
    uint32_t pos = *(uint32_t *)&TVC_ROM[0x1907] & 0x00ffffff;
    // usb_printf("tvc_lfs_file_read_dest: handle: %p, bytesToRead: %d, pos: %06x\n", fileHandle, bytesToRead, pos);main_loop_task();sleep_ms(50);
    
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

    int bytesRead = lfs_file_read(lfs, fileHandle, bufferAddr, bytesToRead);
    uint8_t res = 0;
    if(bytesRead == bytesToRead) {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)bytesRead;
        res = 0;
    } else if(bytesRead == 0) {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)0;
        res = LFS_ERR_END_OF_FILE;
    } else {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)0;
        res = bytesRead;
    }

    // usb_printf("tvc_lfs_file_read_dest: res: %d, bytesRead: %d\n", res, bytesRead);main_loop_task();sleep_ms(50);
    return res;
}

uint8_t tvc_lfs_file_write_source(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *)( *(uint32_t *)&TVC_ROM[0x1900]);
    // usb_printf("tvc_lfs_file_write_dest: fileHandle: %p\n", fileHandle);main_loop_task();sleep_ms(50);

    if(!is_file_handle_valid(fileHandle))
        return 20;

    uint32_t bytesToWrite = (*(uint32_t *)&TVC_ROM[0x1904]) & 0x00ffffff;
    uint32_t pos = *(uint32_t *)&TVC_ROM[0x1907] & 0x00ffffff;

    void *bufferAddr;
    if(pos & 0x800000) {
        // PSRAM address
        pos &= 0x7FFFFF;
        if(psram_size() < (pos + bytesToWrite)) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&psram_array[pos];
    } else {
        // usb_printf("tvc_lfs_file_write_dest: handle: %p, bytesToWrite: %d, pos: %06x\n", fileHandle, bytesToWrite, pos);main_loop_task();sleep_ms(50);
        if( (bytesToWrite == 0) || ((bytesToWrite + pos) > 256*1024) ) {
            return FR_INVALID_PARAMETER;
        }
        bufferAddr = (void *)&TVC_RAM[pos];
    }

    int bytesWritten = lfs_file_write(lfs, fileHandle, bufferAddr, bytesToWrite);
    uint8_t res = 0;
    if(bytesWritten == bytesToWrite) {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)bytesWritten;
        res = 0;
    } else {
        *(uint32_t *)&TVC_ROM[0x1a00] = (uint32_t)0;
        res = bytesWritten;
    }

    // usb_printf("tvc_lfs_file_write_dest: res: %d, bytesWritten: %d\n", res, bytesWritten);main_loop_task();sleep_ms(50);
    return res;
}

uint8_t tvc_lfs_getcwd(char *working_dir) {
    int len = strlen(working_dir);
    TVC_ROM[0x1a00] = len;
    memcpy((void *)&TVC_ROM[0x1a01], working_dir, len);
    // usb_printf("tvc_lfs_getcwd: working_dir: %s\r\n", working_dir); main_loop_task();sleep_ms(50);
    return 0;
}

uint8_t tvc_lfs_chdir(lfs_t *lfs, char *working_dir) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string
    char *newPath = (char *)&TVC_ROM[0x1901];
    str_tolower(newPath);
    // usb_printf("tvc_lfs_chdir: newPath: %s\r\n", newPath); main_loop_task();sleep_ms(50);

    if((len > 1) && (newPath[len-1] == '*')) {
        lfs_dir_open(lfs, &dir_handle, working_dir);
        newPath[len-1] = 0;
        int res = 0;
        while((res = lfs_dir_read(lfs, &dir_handle, &info)) > 0) {
            if((info.type == LFS_TYPE_DIR) && (strstr(info.name, newPath) == info.name)) {
                strncpy(newPath, info.name, 255);
                newPath[255] = 0;
                break;
            }
        }
        lfs_dir_close(lfs, &dir_handle);
        if(res == 0) {
            return FR_NO_PATH;
        }
    }

    strcpy(temp_path, working_dir);
    if(newPath[0] == '/') {
        strncpy(temp_path, newPath, 255);
        temp_path[255] = '\0';
    } else if (newPath[0] == '.' && newPath[1] == '/') {
        if(strlen(working_dir) + strlen(newPath) - 2 >= 256) {
            return FR_INVALID_NAME; // Filename too long
        }
        strcat(temp_path, newPath + 2);
    } else {
        if((newPath[len-1] != '/') && (len<255)) {
            strcat(newPath, "/");
            len++;
        } else {
            return FR_INVALID_NAME;
        }
        if(strlen(working_dir) + strlen(newPath) >= 256) {
            return FR_INVALID_NAME; // Filename too long
        }
        strcat(temp_path, newPath);
    }

    // usb_printf("tvc_lfs_chdir: combined path before normalization: %s\n", temp_path); main_loop_task();sleep_ms(50);

    char *pos = strstr(temp_path, "//");
    while(pos) {
        strcpy(pos, pos+1);
        pos = strstr(temp_path, "//");
    }

    pos = strstr(temp_path, "..");

    while(pos) {
        if(pos==(temp_path+1)) {
            strcpy(pos, pos+2);
        } else {
            char *prevSlash = pos - 2;
            while((prevSlash!=temp_path) && (*prevSlash != '/')) 
                prevSlash--;
            strcpy(prevSlash, pos+2);
        }

        pos = strstr(temp_path, "..");
    }

    
    // usb_printf("tvc_lfs_chdir: newPath: %s, temp_path: %s\r\n", newPath, temp_path); main_loop_task();sleep_ms(50);
    struct lfs_info info;
    int res = lfs_stat(lfs, temp_path, &info);
    // usb_printf("tvc_lfs_chdir: res: %d\n", res); main_loop_task();sleep_ms(50);
    if(res < 0) {
        return FR_NO_PATH; // Path does not exist
    } else if(info.type != LFS_TYPE_DIR) {
        return FR_NO_PATH; // Not a directory
    } else {
        int tplen = strlen(temp_path);
        if((tplen<254) && (temp_path[tplen-1] != '/')) {
            temp_path[tplen] = '/';
            temp_path[tplen+1] = 0;
        }

        strncpy(working_dir, temp_path, 255);
        working_dir[255] = 0;
        return 0; // Success
    }
}

uint8_t tvc_lfs_mkdir(lfs_t *lfs, char *working_dir) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string
    char *dirName = (char *)&TVC_ROM[0x1901];
    // usb_printf("tvc_lfs_mkdir: dirName: %s\r\n", dirName);main_loop_task();sleep_ms(100);
    if(strlen(temp_path) + strlen(dirName) >= 256) {
        return FR_INVALID_NAME; // Filename too long
    }
    str_tolower(dirName);
    strcpy(temp_path, working_dir);
    strcat(temp_path, dirName);
    // usb_printf("tvc_lfs_mkdir: full path: %s\n", temp_path);main_loop_task();sleep_ms(100);
    int res = lfs_mkdir(lfs, temp_path);
    // usb_printf("tvc_lfs_mkdir: res: %d\r\n", res);main_loop_task();sleep_ms(100);
    return res;
}

uint8_t tvc_lfs_delete(lfs_t *lfs, char *working_dir) {
    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string
    char *fileName = (char *)&TVC_ROM[0x1901];
    // usb_printf("tvc_lfs_delete: filename: %s\r\n", fileName);main_loop_task();sleep_ms(50);
    if(strlen(temp_path) + strlen(fileName) >= 256) {
        return FR_INVALID_NAME; // Filename too long
    }
    str_tolower(fileName);
    strcpy(temp_path, working_dir);
    strcat(temp_path, fileName);
    // usb_printf("tvc_lfs_delete: full path: %s\r\n", temp_path);main_loop_task();sleep_ms(50);
    int res = lfs_remove(lfs, temp_path);
    return res;
}

uint8_t tvc_lfs_getstat(lfs_t *lfs, char *working_dir) {

    uint8_t len = TVC_ROM[0x1900];
    if(len == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + len] = 0x00; // Null-terminate the string
    char *fileName = (char *)&TVC_ROM[0x1901];
    if(strlen(temp_path) + strlen(fileName) >= 256) {
        return FR_INVALID_NAME; // Filename too long
    }
    str_tolower(fileName);
    strcpy(temp_path, working_dir);
    strcat(temp_path, fileName);
    // usb_printf("tvc_lfs_getstat: full path: %s\r\n", temp_path);main_loop_task();sleep_ms(50);
    struct lfs_info info;
    int res = lfs_stat(lfs, temp_path, &info);
    if(res == 0) {
        int l = strlen(info.name);
        TVC_ROM[0x1a00] = l;
        memcpy((void *)&TVC_ROM[0x1a01], info.name, l);

        TVC_ROM[0x1b00] = (info.type == LFS_TYPE_DIR) ? 0x10 : 0x01; // Store file type (directory or regular, readonly file)
        if(info.type == LFS_TYPE_REG) {
            *(uint32_t *)&TVC_ROM[0x1b01] = (uint32_t)info.size;
        } else {
            *(uint32_t *)&TVC_ROM[0x1b01] = 0;
        }

        int len = strlen(info.name);
        if(len>12) {
            TVC_ROM[0x1b05] = 12; // Store short filename length
            int pos = len-1;
            while((pos>=0) && (info.name[pos]!='.')) 
                pos--;

            if(pos < len-4) {
                memcpy((void *)&TVC_ROM[0x1b06], info.name, 11); // Store short filename if no extension
                TVC_ROM[0x1b06 + 11] = '~';
            } else {
                memcpy((void *)&TVC_ROM[0x1b06], info.name, 7);
                TVC_ROM[0x1b06 + 7] = '~';
                TVC_ROM[0x1b06 + 8] = '.';
                memcpy((void *)&TVC_ROM[0x1b06 + 9], &info.name[pos+1], MIN(3, len-pos-1));
            }
        } else {
            TVC_ROM[0x1b05] = 0; // No short filename
        }
    }
    return res;
}

uint8_t tvc_lfs_sync(lfs_t *lfs) {
    lfs_file_t *fileHandle = (lfs_file_t *)( *(uint32_t *)&TVC_ROM[0x1900]);
    if(!is_file_handle_valid(fileHandle)) {
        return 20;
    }
    return lfs_file_sync(lfs, fileHandle);
}

uint8_t tvc_lfs_file_rename(lfs_t *lfs, char *working_dir) {
    uint8_t lenOld = TVC_ROM[0x1900];
    uint8_t lenNew = TVC_ROM[0x1901 + lenOld];
    if(lenOld == 0 || lenNew == 0) {
        return FR_INVALID_PARAMETER; // Invalid filename length
    }
    TVC_ROM[0x1901 + lenOld] = 0x00; // Null-terminate the old filename
    TVC_ROM[0x1902 + lenOld + lenNew] = 0x00; // Null-terminate the new filename
    char *oldName = (char *)&TVC_ROM[0x1901];
    char *newName = (char *)&TVC_ROM[0x1902 + lenOld];
    str_tolower(oldName);
    str_tolower(newName);
    
    if(strlen(temp_path) + strlen(oldName) >= 256 || strlen(temp_path) + strlen(newName) >= 256) {
        return FR_INVALID_NAME; // Filename too long
    }
    
    strcpy(temp_path, working_dir);
    strcat(temp_path, oldName);
    char oldPath[256];
    strcpy(oldPath, temp_path);
    
    strcpy(temp_path, working_dir);
    strcat(temp_path, newName);
    
    return lfs_rename(lfs, oldPath, temp_path);
    
}

/**
 * Mount a dsk file
 * IN:
 *  0x1900 File name
 * OUT:
 *  
 */

extern uint8_t dsk_file_type;
lfs_file_t dsk_file_lfs;
lfs_t *dsk_lfs_fs;
extern FATFS dsk_fat_fs;
void set_active_drive(uint8_t ld_num);

uint8_t tvc_lfs_mount_dsk(lfs_t *lfs, uint8_t dsk_target_file_type) {
    uint8_t len = TVC_ROM[0x1900];
    char fNameBuf[256];
    TVC_ROM[0x1901 + len] = 0;
    // usb_printf("lfs dsk mount: fName: %s\n", fNameBuf);sleep_ms(50);
    if(dsk_file_type != 0) {
        return FR_NOT_READY;
    }
    strcpy(fNameBuf, (char *)&TVC_ROM[0x1901]);

    int retVal = lfs_file_open(lfs, &dsk_file_lfs, fNameBuf, LFS_O_RDWR);
    // usb_printf("lfs dsk fopen: fName: %s, res: %d\n", fNameBuf, retVal);sleep_ms(50);
    if(retVal != 0) {
        return FR_NO_FILE;
    }

    dsk_file_type = dsk_target_file_type;
    dsk_lfs_fs = lfs;

    // usb_printf("mount: f_open res: %02x\n", fres);sleep_ms(50);
    FRESULT fres = f_mount(&dsk_fat_fs, "1:", 1);
    // usb_printf("lfs dsk fmount: res: %d\n", fres);sleep_ms(50);
    // usb_printf("mount: f_mount res: %02x\n", fres);sleep_ms(50);
    if(fres != FR_OK) {
        lfs_file_close(lfs, &dsk_file_lfs);
        dsk_file_type = 0;
        set_active_drive(0);
    }

    TVC_ROM[0x1825] = (fres == FR_OK);

    // usb_printf("mount: fres: %02x\n", fres);sleep_ms(50);
    return fres;
}

uint8_t tvc_lfs_unmount_dsk() {
    if((dsk_file_type == 2) || (dsk_file_type == 3)) {
        set_active_drive(0);
        f_unmount("1:");
        lfs_file_close(dsk_lfs_fs, &dsk_file_lfs);
        if(TVC_ROM[0x1810] == 3) // if active drive was DSK, then set it to either PSRAM or FLASH drive
            TVC_ROM[0x1810] = dsk_file_type - 1;

        dsk_file_type = 0;
        TVC_ROM[0x1825] = 0;
    } else {
        return FR_INVALID_OBJECT;
    }

    return FR_OK;
}
