/*
 * dac7578.h
 *
 * Created: 2/22/2021 10:42:28 AM
 *  Author: vcruchet, hliverud
 */
#ifndef DAC7578_H_
#define DAC7578_H_

#include "config.h"
#include <Wire.h>
#include <stdint.h>
#include <stdbool.h>

#define DAC7578_WRU_CMD	0x0
#define DAC7578_RD_CMD	0x1
#define DAC7578_RST_CMD 0b0111 // software reset

#define DAC_I2C_WR_PCKT_LEN     3 // command, MSB, LSB
#define DAC_I2C_RD_PCKT_LEN     2 // MSB, LSB

class DAC7578 {
public:
    uint8_t address;
    uint16_t channel_val[DAC7578_NCH];
};

// Initializes ACCURATE_DAC fields with given address and default channel values
void dac7578_init(uint8_t addr);

// set ACCURATE_DAC address
void dac7578_set_addr(uint8_t addr);

// set ACCURATE_DAC's channel(ch_idx) value
void dac7578_set_ch_val(uint8_t ch_idx, uint16_t ch_val, bool update);

// get ACCURATE_DAC address
uint8_t dac7578_get_addr();

// get ACCURATE_DAC channels value
// returns a pointer to the array of length DAC_NCH
uint16_t* dac7578_get_all_ch();

// returns the channel value
uint16_t dac7578_get_ch_val(uint8_t ch_idx);

// send all channel parameters contained in the structure via i2c 
void dac7578_i2c_send_all_param();

#endif /* DAC7578_H_ */
