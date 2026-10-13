/*
 * sid.h
 *
 *  Created on: 2022. okt. 12.
 *      Author: sanyi
 */

#ifndef _SID_H_
#define _SID_H_
#include "pico/stdlib.h"

#define CLOCK_ACCURACY 10

extern volatile uint16_t main_volume;

void reset_SID();
void setregister_SID(uint8_t addr,uint8_t value);

void calculate_SID_voices(uint16_t skippedClocks);
void apply_SID_filter(uint8_t skippedClocks);
void apply_SID_FILTER(uint8_t skippedClocks);
void prepare_for_filter();
void prepare_for_output();
void prepare_unfiltered_output();

#endif /* _SID_H_ */
