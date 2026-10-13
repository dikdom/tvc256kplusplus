#include "tvc-sound.h"
#include "tvc-sid.h"
#include "hardware/irq.h"
#include <hardware/dma.h>
#include <hardware/pwm.h>
#include <hardware/ticks.h>
#include "pico/time.h"
#include "pico/stdlib.h"
#include "pico/stdlib.h"
#include "TVC-IO-main-gfx.h"

#define ALARM_NUM 0
#define AUDIO_DMA_CHANNEL 3
#define AUDIO_DMA_IRQ 0

#define ALARM_IRQ timer_hardware_alarm_get_irq_num(timer1_hw, ALARM_NUM)


#define BITS_OF_NUM_OF_SAMPLES 8
#define NUM_OF_SAMPLES (1 << BITS_OF_NUM_OF_SAMPLES)

#define MAX_PWM_VALUE 2045
#define MAX_DOUBLE_PWM_VALUE 255
#define CLOCK_PER_TICK 341

uint32_t __aligned(1<<(2+BITS_OF_NUM_OF_SAMPLES)) audio_samples[NUM_OF_SAMPLES];
volatile uint8_t sidQueueWritePos = 0;
volatile uint8_t sidQueueReadPos = 0;
sid_write_queue_t sid_write_queue[256];

/**
 A)
 PWM: 4096 / 336000000 => 82.03125kHz
 
 tick: 256 / 336000000 = 1.3125MHz
 alarm: 4 * 64 tick => 4 * 16384 / 336000000

 DMA: 16384 / 336000000 -> 20.508kHz

=======================
 B) SELECTED OPTION - OLD
 PWM = (341*6 =) 2046 / 336000000 => 164.22287kHz
 tick: 341 / 336000000 => 985kHz
 DMA: (48*341=)16368 / 336000000 -> 20.527kHz
 uint32_t -> 4358.8s=1hour12mins

=======================
 C)
 PWM:  1024 / 336000000 => 328.125kHz
 tick:  256 / 336000000 => 1.3125MHz
 alarm:  (NUM_OF_SAMPLES/2)*64 tick => 32 * 16368 / 336000000 => 20507.8125kHz / 32 ~ 1kHz

=======================
D) SELECTED OPTION
 PWMLO: 336000000 / 256 => 1.3125MHz
 PWMHI: 336000000 / 256  => 1.3125MHz
 tick:  336000000 / 341 => 985kHz
 DMA: (24*341=)16368 / 336000000 -> 41kHz
*/



uint32_t prevSampleTime = 0;
uint8_t samplePosStart = 0;
uint16_t remainingClocks = 0;
uint32_t timerCycle = 0;
bool first_half = true;
volatile uint32_t called_num = 0;
uint32_t maxDiff = 0 ;
extern uint8_t TVC_RAM[];
uint64_t prev_timer1_64 = 0;
uint64_t timeStamp = 0;



void own_print_hex_word(uint32_t word, int idx) {
    uint8_t* pos = (uint8_t*)&TVC_RAM[0x0400+20*32 + 10 + idx*10];
    *(pos++) = ((word >> 28) & 0xf) < 10 ? ((word >> 28) & 0xf) + '0' : ((word >> 28) & 0xf) - 9;
    *(pos++) = ((word >> 24) & 0xf) < 10 ? ((word >> 24) & 0xf) + '0' : ((word >> 24) & 0xf) - 9;
    *(pos++) = ((word >> 20) & 0xf) < 10 ? ((word >> 20) & 0xf) + '0' : ((word >> 20) & 0xf) - 9;
    *(pos++) = ((word >> 16) & 0xf) < 10 ? ((word >> 16) & 0xf) + '0' : ((word >> 16) & 0xf) - 9;
    *(pos++) = ((word >> 12) & 0xf) < 10 ? ((word >> 12) & 0xf) + '0' : ((word >> 12) & 0xf) - 9;
    *(pos++) = ((word >> 8) & 0xf) < 10 ? ((word >> 8) & 0xf) + '0' : ((word >> 8) & 0xf) - 9;
    *(pos++) = ((word >> 4) & 0xf) < 10 ? ((word >> 4) & 0xf) + '0' : ((word >> 4) & 0xf) - 9;
    *(pos++) = (word & 0xf) < 10 ? (word & 0xf) + '0' : (word & 0xf) - 9;
}

void calculate_sound_samples() {
    // timeStamp = time_us_64();
    called_num++;
    /**
     * From what point of time we calculate the samples?
     * 
     * Let's assume we have a 8 sample long dma buffer, the actual timing of the first 2x 8 DMA 
     * transfers looks like this (these are 985kHz clock ticks, counted by TIMER1)
     * 
     *    0   48    96   144   192   240   288   336
     *  384  432   480   528   576   624   672   720
     * 
     * The first interrupt is raised at finishing the tx at the 144. Then the IRQ handler routine
     * starts to calculate from the timestamp of 0 (register writes are available from 0-144)
     * and places the results to the first half of the buffer.
     * The second interrupt is raised at finishing the tx at the 336. Then the IRQ handler routine
     * shall calculate the samples from 144 (!) to 336 and shall put the results into the second
     * half of the buffer (while the DMA start transferring samples from the first half of
     * the buffer). Please note that when does the calculation timing start at the very first and
     * any other half-buffer calculations. At the very first it starts at the start time of the half
     * buffer (0) while the other the calulation starts from the last timestamp of the previous half
     * buffer (144, 336, etc...)
     * The third interrupt is raised at finishing the tx at the 528. Then the IRQ handler routine
     * shall calculate the samples from 336 to 528 and shall put the results into the first
     * half of the buffer.
     * etc...
     * remainingClocks contains how many clocks are skipped from the last to this sample calculation.
     * At the very first calculation it is 0, otherwise it reset to 48 and if there is any register
     * write between the two samples, then oscillators are adjusted until the register write, the
     * registers are updated and then the remaininClocks are adjusted according to the timerstamp of the
     * register write..
     *  
     */

    uint32_t sampleTime = (24 * NUM_OF_SAMPLES / 2) * timerCycle;
/**
    uint64_t t1_64 = timer_time_us_64(timer1_hw);
    uint32_t sid_clk = t1_64 / 341;
    uint32_t diff = sid_clk - sampleTime;
    if(diff>maxDiff) {
        maxDiff = diff;
    }

    own_print_hex_word(maxDiff, 0);
    own_print_hex_word(diff, 1);
    own_print_hex_word(sid_clk, 2);
    own_print_hex_word(sampleTime, 3);
    own_print_hex_word(t1_64 - prev_timer1_64, 4);
    own_print_hex_word(t1_64 / timerCycle, 5);
    own_print_hex_word(((sidQueueWritePos - sidQueueReadPos) << 16) | (sidQueueWritePos<<8) | sidQueueReadPos, 6);

    prev_timer1_64 = t1_64;
*/

    timerCycle++;
    
    for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
        while(sidQueueWritePos!=sidQueueReadPos) {
            uint32_t ts = sid_write_queue[sidQueueReadPos].ts;
            uint16_t qv = sid_write_queue[sidQueueReadPos].address_value;
            if(ts<sampleTime) {
                uint8_t addr = qv>>8;
                uint8_t val = qv & 0xff;
                int32_t diff = ts-prevSampleTime;
                if(diff>0) {
                    calculate_SID_voices(diff);
                    remainingClocks -= diff;
                    prevSampleTime = ts;
                }
                setregister_SID(addr, val);
                sidQueueReadPos++;
            } else {
                break;
            }
        }
        if(remainingClocks>0) {
            calculate_SID_voices(remainingClocks);
        }
        remainingClocks = 24;
        
        // prepare_for_filter();
        // apply_SID_filter(0);
        // prepare_for_output();
        prepare_unfiltered_output();
        // audio_samples[samplePosStart + i] = main_volume; // single PWM output
        audio_samples[samplePosStart + i] = (main_volume & 0xff) | ((main_volume & 0xff00) << 8); // double PWM output

        prevSampleTime = sampleTime;
        sampleTime += 24;
    }

    samplePosStart = (samplePosStart==0 ? NUM_OF_SAMPLES / 2 : 0);
    dma_hw->ints0 = 1u<<AUDIO_DMA_CHANNEL;
    // own_print_hex_word(time_us_64() - timeStamp, 0);
}

uint32_t prevSample = 0;
int32_t value3=0;
int8_t dir3 = 1;
extern uint8_t SID[32];
volatile int32_t value4=0;
volatile int32_t value5=0;
volatile int32_t value7=0;
volatile int32_t dir7 = 1;
volatile int32_t diff = 1;

void calculate_dummy_samples() {
    uint32_t startV = 0;
    while(sidQueueReadPos != sidQueueWritePos) {
        uint16_t qv = sid_write_queue[sidQueueReadPos].address_value;
        setregister_SID(qv>>8, qv & 0xff);
        sidQueueReadPos++;
    }
    called_num++;
    switch((SID[24] & 0xf0)>>4) {
        case 0:
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                uint32_t sampleTime = prevSampleTime + 64;
                
                audio_samples[samplePosStart + i] = samplePosStart==0 ? MAX_PWM_VALUE * (SID[24] & 0x0f) / 15 : 0;
        
                prevSampleTime = sampleTime;
            }
            break;
        case 1:
            startV = (samplePosStart == 0 ? 0 : MAX_PWM_VALUE >> 1);
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = startV + i * (MAX_PWM_VALUE >> 1 ) / (NUM_OF_SAMPLES / 2);
            }
            break;
        case 2: 
            startV = (samplePosStart == 0? 0 : MAX_PWM_VALUE);
            diff = samplePosStart == 0 ? MAX_PWM_VALUE / (NUM_OF_SAMPLES/2) : -1*(MAX_PWM_VALUE / (NUM_OF_SAMPLES/2));
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = startV + i * diff;
            }
            break;
        case 3:
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = value3;
                int8_t diff = dir3 * SID[0];
                value3 += diff;
                if((dir3 > 0) && (value3>MAX_PWM_VALUE)) {
                    dir3 = -1;
                    value3 = 2 * MAX_PWM_VALUE - value3;
                } else if(value3<0) {
                    dir3 = 1;
                    value3 = -1 * value3;
                }
            }
            break;
        case 4:
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = value4;
                value4 += SID[0];
                if(value4>MAX_PWM_VALUE) {
                    value4 = 0;
                }
            }
            break;
        case 5:
            // samplePosStart = dma_hw->ch[AUDIO_DMA_CHANNEL].transfer_count > (NUM_OF_SAMPLES / 2) ? NUM_OF_SAMPLES / 2 : 0;
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = value5;
                value5 = (SID[0] + value5) & MAX_PWM_VALUE;
            }
            break;
        case 6:
            // samplePosStart = (dma_hw->ch[AUDIO_DMA_CHANNEL].transfer_count & 0x0fffffff) > (NUM_OF_SAMPLES / 2) ? NUM_OF_SAMPLES / 2 : 0;
            samplePosStart = first_half ? 0 : NUM_OF_SAMPLES / 2;
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                audio_samples[samplePosStart + i] = value5;
                value5 = (SID[0] + value5) & MAX_PWM_VALUE;
            }
            break;            
        case 7:
            samplePosStart = first_half ? 0 : NUM_OF_SAMPLES / 2;
            for(int i=0; i < (NUM_OF_SAMPLES/2); i++) {
                value7 = value7 + dir7 * SID[0];
                if((dir7>0) && (value7>MAX_PWM_VALUE)) {
                    value7 = 2*MAX_PWM_VALUE - value7;
                    dir7 =  -1;
                } else if((dir7<0) && (value7<0)) {
                    value7 = -1 * value7;
                    dir7 = 1;
                }
                audio_samples[samplePosStart + i] = value7;
            }
            break;            
            
    }

    first_half = !first_half;

    samplePosStart = samplePosStart==0 ? NUM_OF_SAMPLES / 2 : 0;

    // timer1_hw->alarm[0] = (NUM_OF_SAMPLES / 2) * 64 * (timerCycle++);
    // hw_clear_bits(&timer1_hw->intr, 1u << ALARM_NUM);
    dma_hw->ints0 = 1u<<AUDIO_DMA_CHANNEL;
    // dma_hw->irq_ctrl[AUDIO_DMA_IRQ].ints = 1<<AUDIO_DMA_CHANNEL;
}

/**
 * Fill buffer with the mean value of the audio output
 */
void fill_buffer() {
    for(int i=0; i<NUM_OF_SAMPLES; i++)
        audio_samples[i] = 0x0000;
}

void init_sound_pwms() {
    uint slice_num = pwm_gpio_to_slice_num(PIN_SOUND_LO);
    gpio_set_function(PIN_SOUND_LO, GPIO_FUNC_PWM);

    
    pwm_set_wrap(slice_num, MAX_DOUBLE_PWM_VALUE);
    pwm_set_gpio_level(PIN_SOUND_LO, MAX_DOUBLE_PWM_VALUE>>1);

    slice_num = pwm_gpio_to_slice_num(PIN_SOUND_HI);
    gpio_set_function(PIN_SOUND_HI, GPIO_FUNC_PWM);
    
    pwm_set_wrap(slice_num, MAX_DOUBLE_PWM_VALUE);
    pwm_set_gpio_level(PIN_SOUND_HI, MAX_DOUBLE_PWM_VALUE>>1);

}

void init_calculate_sample_timer() {
    tick_stop(TICK_TIMER1);
    timer1_hw->pause = 1;
    timer1_hw->timelw = 0;
    timer1_hw->timehw = 0;
    timer1_hw->source = 1;
    timer1_hw->pause = 0;
    
    // Enable the interrupt for our alarm (the timer outputs 4 alarm irqs)
    // hw_set_bits(&timer1_hw->inte, 1u << ALARM_NUM);


    // timer1_hw->alarm[ALARM_NUM] = (NUM_OF_SAMPLES / 2) * 64 * (timerCycle++);
    // Set irq handler for alarm irq
    // irq_set_exclusive_handler(ALARM_IRQ, calculate_dummy_samples);
    // Enable the alarm irq
    // irq_set_enabled(ALARM_IRQ, true);

    // irq_set_priority(TIMER1_IRQ_0, 0x00);
    // irq_set_priority(TIMER0_IRQ_0, 0x80);
}

void init_sound_sample_dma() {
    dma_channel_config_t dma_ch_config = dma_channel_get_default_config(AUDIO_DMA_CHANNEL);
    channel_config_set_read_increment(&dma_ch_config, true);
    channel_config_set_write_increment(&dma_ch_config, false);
    // channel_config_set_dreq(&dma_ch_config, DREQ_DMA_TIMER0);
    channel_config_set_dreq(&dma_ch_config, DREQ_PWM_WRAP0);
    channel_config_set_transfer_data_size(&dma_ch_config, DMA_SIZE_32);
    channel_config_set_ring(&dma_ch_config, false, 2 + BITS_OF_NUM_OF_SAMPLES);

    dma_irqn_set_channel_enabled(AUDIO_DMA_IRQ, AUDIO_DMA_CHANNEL, true);
    // irq_set_exclusive_handler(DMA_IRQ_0 + AUDIO_DMA_IRQ, calculate_dummy_samples);
    irq_set_exclusive_handler(DMA_IRQ_0 + AUDIO_DMA_IRQ, calculate_sound_samples);
    irq_set_enabled(DMA_IRQ_0 + AUDIO_DMA_IRQ, true);

    dma_timer_set_fraction(0, 1, 16368);

    dma_channel_configure(AUDIO_DMA_CHANNEL, 
                          &dma_ch_config,
                          &pwm_hw->slice[pwm_gpio_to_slice_num(PIN_SOUND_LO)].cc, // Destination pointer
                          &audio_samples[0],        // Source pointer
                          dma_encode_transfer_count_with_self_trigger(NUM_OF_SAMPLES/2),       // Number of transfers
                          false                     // Don't start
    );
}

void init_pacing_pwm() {
    // We use PWM slice 0 as the pacing source for the DMA, so we need to set it up
    pwm_set_wrap(0, 341*24-1); // 24 cycles of 341 ticks is around 41kHz, which is a good sample rate for the audio output
}

void start_all() {
    uint slice_num = pwm_gpio_to_slice_num(PIN_SOUND_LO);
    dma_channel_start(AUDIO_DMA_CHANNEL);
    pwm_set_enabled(0, true);
    pwm_set_enabled(slice_num, true);
}

void init_sound_subsystem(void) {
    reset_SID();
    fill_buffer();
    init_sound_pwms();
    init_pacing_pwm();
    init_calculate_sample_timer();
    init_sound_sample_dma();
    start_all();
}