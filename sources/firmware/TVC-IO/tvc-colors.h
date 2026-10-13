
#ifndef TVC_COLORS_H
#define TVC_COLORS_H


typedef uint8_t color_t;

/*
EC0 - intensity
EC1 - red
EC2 - green
EC3 - blue
*/

#define EC_LIGHT 0b0001

#define EC_BLACK 0b0000
#define EC_RED   0b0010
#define EC_GREEN 0b0100
#define EC_BLUE  0b1000
#define EC_PURPLE (EC_BLUE + EC_RED)
#define EC_CYAN   (EC_BLUE + EC_GREEN)
#define EC_BROWN  (EC_RED + EC_GREEN)
#define EC_GRAY   (EC_BLUE + EC_RED + EC_GREEN)
#define LTEC_BLACK   (EC_LIGHT + EC_BLACK)
#define LTEC_BLUE    (EC_LIGHT + EC_BLUE)
#define LTEC_RED     (EC_LIGHT + EC_RED)
#define LTEC_GREEN   (EC_LIGHT + EC_GREEN)
#define LTEC_PURPLE  (EC_LIGHT + EC_PURPLE)
#define LTEC_CYAN    (EC_LIGHT + EC_CYAN)
#define LTEC_BROWN   (EC_LIGHT + EC_BROWN)
#define LTEC_GRAY    (EC_LIGHT + EC_GRAY)
#define EC_YELLOW LTEC_BROWN
#define EC_WHITE LTEC_GRAY


#define LIGHT 0b1000
#define TVC_BLACK 0b0000
#define TVC_RED   0b0100
#define TVC_GREEN 0b0010
#define TVC_BLUE  0b0001
#define TVC_PURPLE (TVC_BLUE + TVC_RED)
#define TVC_CYAN   (TVC_BLUE + TVC_GREEN)
#define TVC_BROWN  (TVC_RED + TVC_GREEN)
#define TVC_GRAY   (TVC_BLUE + TVC_RED + TVC_GREEN)
#define LT_BLACK   (LIGHT + TVC_BLACK)
#define LT_BLUE    (LIGHT + TVC_BLUE)
#define LT_RED     (LIGHT + TVC_RED)
#define LT_GREEN   (LIGHT + TVC_GREEN)
#define LT_PURPLE  (LIGHT + TVC_PURPLE)
#define LT_CYAN    (LIGHT + TVC_CYAN)
#define LT_BROWN   (LIGHT + TVC_BROWN)
#define LT_GRAY    (LIGHT + TVC_GRAY)


#define TVC_YELLOW LT_BROWN
#define TVC_WHITE LT_GRAY


/**
const color_t ec_colors[] = {EC_BLACK, EC_RED, EC_GREEN, EC_BLUE, EC_PURPLE, EC_CYAN, EC_BROWN, EC_GRAY,
                             LTEC_BLACK,  LTEC_BLUE, LTEC_RED,    LTEC_GREEN, LTEC_PURPLE,  LTEC_CYAN,  LTEC_BROWN,  EC_WHITE};
const color_t tvc_colors[] = {TVC_BLACK, TVC_RED, TVC_GREEN, TVC_BLUE, TVC_PURPLE, TVC_CYAN, TVC_BROWN, TVC_GRAY,
                             LT_BLACK,  LT_BLUE, LT_RED,    LT_GREEN, LT_PURPLE,  LT_CYAN,  LT_BROWN,  TVC_WHITE};
*/

#endif