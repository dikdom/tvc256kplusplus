#include <stdint.h>

typedef uint8_t (*tvc_function_t)(uint8_t* bufferStart);

typedef struct {
    tvc_function_t func;
    uint8_t param_size;
} tvc_function_struct_t;

typedef enum {
    FINISH = 0,
    // operations, 2 ops
    ADD,
    SUB,
    MUL,
    DIV,
    MAX,
    MIN,
    // operations, 1 op
    ABS,
    SQR,
    SQRT,
    SIN,
    COS,
    TAN,
    TOINT,
    TOFLOAT,
    ROUND,
    // data types
    TYPE_UINT8 = 0x40,
    TYPE_INT16,
    TYPE_INT32,
    TYPE_TVCFLOAT,
    TYPE_FLOAT,
    TYPE_VARREF,
    CONST_2PI = 0x80,
    CONST_PI,
    CONST_PI2,
    CONST_0_001,
    CONST_0_01,
    CONST_0_1,
    CONST_1,
    CONST_10,
    CONST_100,
    CONST_1000
} OP_OR_PTYPES;

typedef union value {
    int32_t vali;
    float valf;
} values_t;

typedef struct{
    OP_OR_PTYPES type;
    values_t value;
} operation_stack_element_t;


uint8_t clear_text_screen(uint8_t* bufferStart);
uint8_t clear_bitmap_screen(uint8_t* bufferStart);
uint8_t print_character_screen_code(uint8_t* bufferStart);
uint8_t print_string_screen_code(uint8_t* bufferStart);
uint8_t print_string_ascii(uint8_t* bufferStart);
uint8_t print_hex_byte(uint8_t* bufferStart);
uint8_t print_hex_word(uint8_t* bufferStart);
uint8_t goto_xy(uint8_t* bufferStart);
uint8_t set_xy(uint8_t* bufferStart);
uint8_t get_xy(uint8_t* bufferStart);
uint8_t set_text_color(uint8_t* bufferStart);
uint8_t get_text_color(uint8_t* bufferStart);
uint8_t replace_pixel_color(uint8_t* bufferStart);
uint8_t getFunctionParamSize(uint8_t *bufStart, uint8_t paramSize);


/*
void print_hex_digit(uint8_t digit);
void clear_text_screen(uint8_t* bufferStart);
void clear_bitmap_screen(uint8_t* bufferStart);
void print_character_screen_code(uint8_t* bufferStart);
void print_hex_byte(uint8_t* bufferStart);
void print_hex_word(uint8_t* bufferStart);
void print_string_screen_code(uint8_t* bufferStart);
void print_string_ascii(uint8_t* bufferStart);
void goto_xy(uint8_t* bufferStart);
*/


void init_routines();