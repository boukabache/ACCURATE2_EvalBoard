/*
 * dac7578.h
 *
 * Created: 2/22/2021 10:42:28 AM
 *  Author: vcruchet, hliverud
 */
#ifndef DAC7578_H_
#define DAC7578_H_

#include <Wire.h>
#include <stdint.h>
#include <stdbool.h>

#define DAC_ADDRESS		0x0048

#define DAC7578_NCH		8
#define VBIAS1_CH		0
#define VCM_CH			1
#define VTH1_CH			2
#define VCHARGEP_CH		3
#define VTH2_CH			4
#define VTH4_CH			5
#define VTH3_CH			6
#define VBIAS3_CH		7

#define VBIAS1_REG		0x0D00
#define VCM_REG			0x0A00
#define VTH1_REG		0x0F00
#define VCHARGEP_REG	0x1000
#define VTH2_REG		0x0E00
#define VTH4_REG		0x1000
#define VTH3_REG		0x1000
#define VBIAS3_REG		0x0700

#define DAC7578_WRU_CMD	0x0
#define DAC7578_RD_CMD	0x1

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
