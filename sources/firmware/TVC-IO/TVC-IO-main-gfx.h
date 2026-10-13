#ifndef TVC_IO_CORE0_H
#define TVC_IO_CORE0_H

#define BOARD_RP2350A_PROTOTYPE 0
#define BOARD_RP2350B_PROTOTYPE 0
#define BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0 0    // rev0 WeAct Studio RP2350B
#define BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0   0    // WaveShare Core 2350B
#define BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 0    // rev1 WeAct Studio RP2350B
#define BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2 1    // rev WeAct Studio RP2350B


#include <stdio.h>
#include "pico/stdlib.h"

#if BOARD_RP2350A_PROTOTYPE
#define PIN_EXPn 0
#define PIN_P2 1
#define PIN_P3 2
#define PIN_RD 3
#define PIN_WR 4
#define PIN_SLOTn 5
#define PIN_A0 6
#define PIN_D0 14       // must be right after the ADDR pins!!
#define PIN_PHANTOM 22  // must be right after the DATA pins
#define ADDRESS_MASK (1<<(PIN_D0 - PIN_A0) - 1)
#elif BOARD_RP2350B_PROTOTYPE
#define PIN_EXPn  1
#define PIN_P2    2
#define PIN_P3    3 
#define PIN_RD    4
#define PIN_WR    5
#define PIN_SLOTn 6
#define PIN_A0    7  // 7-20
#define PIN_BUTTON 23
#define PIN_MREQ 24
#define PIN_LED  25

#define PIN_6M25   26
// nBorder -> paper: BORDER=1, border: BORDER=0
#define PIN_BORDER 27
//HSYNC -> sync: HSYNC=1, screen: HSYNC=0
#define PIN_HSYNC  28
//VSYNC -> sync: VSYNC=1, Vscreen: SYNC=0
#define PIN_VSYNC  29
#define PIN_D0     32
#define PIN_PHANTOM 40
#define PIN_EXTC   41
#define PIN_EC0    42
#define PIN_EC1    43
#define PIN_EC2    44
#define PIN_EC3    45

#define ADDRESS_MASK (1<<(14) - 1)
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0
#define PIN_EXPn 1
#define PIN_MREQ 2
#define PIN_P2 3
#define PIN_P3 4
#define PIN_RD 5
#define PIN_WR 6
#define PIN_SLOTn 7
#define PIN_A0 8  // 8-21
#define PIN_BUTTON 23
#define PIN_LED 25
#define PIN_6M25 26
#define PIN_BORDER 27
#define PIN_HSYNC 28
#define PIN_VSYNC 29

#define PIN_USB_DM 30
#define PIN_USB_DP 31

#define PIN_D0 32
#define PIN_PHANTOM 40
#define PIN_EXTC 41 // transparency
#define PIN_EC0 42  // intensity
#define PIN_EC1 43
#define PIN_EC2 44
#define PIN_EC3 45
#define PIN_INTn 46
#define ADDRESS_MASK ((1<<(14)) - 1)

#elif BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
#define PIN_EXPn 0
#define PIN_MREQ 1
#define PIN_P2 2
#define PIN_P3 3
#define PIN_RD 4
#define PIN_WR 5
#define PIN_SLOTn 6
#define PIN_IORQ 7
#define PIN_INTn 8
#define PIN_A0 9  // A0-A13: 9-22
#define PIN_D0 23
#define PIN_PHANTOM 31

// #define PIN_BUTTON 23
#define PIN_6M25 32
#define PIN_BORDER 33
#define PIN_HSYNC 34
#define PIN_VSYNC 35

#define PIN_LED 39

#define PIN_EC3 40
#define PIN_EC2 41
#define PIN_EC1 42
#define PIN_EC0 43
#define PIN_EXTC 44
#define PIN_PSRAM_CS 47
#define ADDRESS_MASK ((1<<(14)) - 1)

#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1
#define PIN_PSRAM_CS 0
#define PIN_EXPn 1
#define PIN_MREQ 2
#define PIN_P2 3
#define PIN_P3 4
#define PIN_RD 5
#define PIN_WR 6
#define PIN_SLOTn 7
#define PIN_IORQ 8
#define PIN_A0 9  // 9-22
#define PIN_BUTTON 23
#define PIN_RESET 23
#define PIN_INTn 24
#define PIN_LED 25
#define PIN_6M25 26
#define PIN_BORDER 27
#define PIN_HSYNC 28
#define PIN_VSYNC 29
#define PIN_USB_DM 30
#define PIN_USB_DP 31
#define PIN_D0 32
#define PIN_PHANTOM 40
#define PIN_EC1 41
#define PIN_EC2 42
#define PIN_EC3 43
#define PIN_EC0 44
#define PIN_EXTC 45
#define PIN_SOUND_LO 46
#define PIN_SOUND_HI 47
#define ADDRESS_MASK ((1<<(14)) - 1)

#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
#define PIN_PSRAM_CS 0
#define PIN_EXPn 1
#define PIN_MREQ 2
#define PIN_P2 3
#define PIN_P3 4
#define PIN_RD 5
#define PIN_WR 6
#define PIN_SLOTn 7
#define PIN_IORQ 8
#define PIN_A0 9  // 9-22
#define PIN_BUTTON 23
#define PIN_RESET 23
#define PIN_INTn 24
#define PIN_LED 25
#define PIN_6M25 26
#define PIN_BORDER 27
#define PIN_HSYNC 28
#define PIN_VSYNC 29
#define PIN_USB_DM 30
#define PIN_USB_DP 31
#define PIN_D0 32
#define PIN_PHANTOM 40
#define PIN_EC3 41
#define PIN_EC2 42
#define PIN_EC1 43
#define PIN_EC0 44
#define PIN_EXTC 45
#define PIN_SOUND_LO 46
#define PIN_SOUND_HI 47
#define ADDRESS_MASK ((1<<(14)) - 1)



#endif

// extern const unsigned char _binary_tvc_gcfw_bin_start[];
extern const unsigned char _binary____binaries_c16_hungarian_bin_start[];// __attribute__((section(".flashdata")));

// extern const unsigned char _binary____binaries_c16_hungarian_bin_end[];
extern const unsigned char _binary____binaries_c16_hungarian_bin_end[];//   __attribute__((section(".flashdata")));

#define font_bin _binary____binaries_c16_hungarian_bin_start
#define font_len (_binary____binaries_c16_hungarian_bin_end - _binary____binaries_c16_hungarian_bin_start)

extern const unsigned char _binary____binaries_tvc_16cimage_bmp_start[];// __attribute__((section(".flashdata")));
extern const unsigned char _binary____binaries_tvc_16cimage_bmp_end[];//   __attribute__((section(".flashdata")));

#define bkgimg_bin _binary____binaries_tvc_16cimage_bmp_start
#define bkgimg_len (_binary____binaries_tvc_16cimage_bmp_end - _binary____binaries_tvc_16cimage_bmp_start)


void preinit_core_gfx();
void wait_for_valid_vsync();
void main_graphics();

typedef struct __attribute__((packed)) ContextStateFrame {
  uint32_t r0;
  uint32_t r1;
  uint32_t r2;
  uint32_t r3;
  uint32_t r12;
  uint32_t lr;
  uint32_t return_address;
  uint32_t xpsr;
} sContextStateFrame;


#endif