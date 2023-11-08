/*
 * dac7578.cpp
 *
 * Created: 2/22/2021 10:42:28 AM
 *  Author: vcruchet, hliverud
 */
#include "dac7578.h"
#include <Arduino.h>
#include <Time.h>


 /************************************************************************/
 /* GLobal variables definition                                          */
static DAC7578 ACCURATE_DAC;

/************************************************************************/

/************************************************************************/
/* Functions definition                                                 */

// Initializes ACCURATE_DAC fields with given address and default channel values
void dac7578_init(uint8_t addr) {
    ACCURATE_DAC.address = addr;
    ACCURATE_DAC.channel_val[VBIAS1_CH] = VBIAS1_REG;		// default :  1.68 V
    ACCURATE_DAC.channel_val[VCM_CH] = VCM_REG;			    // default :  1.5 V
    ACCURATE_DAC.channel_val[VTH1_CH] = VTH1_REG;			// default :  2.3 V
    ACCURATE_DAC.channel_val[VCHARGEP_CH] = VCHARGEP_REG;	// default :  2.5 V
    ACCURATE_DAC.channel_val[VTH2_CH] = VTH2_REG;			// default :  2.4 V
    ACCURATE_DAC.channel_val[VTH4_CH] = VTH4_REG;			// default :  2.5 V
    ACCURATE_DAC.channel_val[VTH3_CH] = VTH3_REG;			// default :  2.5 V
    ACCURATE_DAC.channel_val[VBIAS3_CH] = VBIAS3_REG;		// default :  1.18 V
}

// set DAC address
void dac7578_set_addr(uint8_t addr) {
    ACCURATE_DAC.address = addr;
}

// set DAC's channel(ch_idx) value
void dac7578_set_ch_val(uint8_t ch_idx, uint16_t ch_val, bool update) {
    ACCURATE_DAC.channel_val[ch_idx] = ch_val;
    if (update) { // directly update the modified channel
        Wire.beginTransmission(ACCURATE_DAC.address);
        Wire.write((DAC7578_WRU_CMD << 4) | ch_idx);
        Wire.write(ch_val >> 4);
        Wire.write(ch_val << 4);
        Wire.endTransmission();
    }
}

// get DAC address
uint8_t dac7578_get_addr() {
    return ACCURATE_DAC.address;
}

// get DAC channels value
// returns a pointer to the array of length DAC_NCH
uint16_t* dac7578_get_all_ch() {
    return ACCURATE_DAC.channel_val;
}

// returns the channel value
uint16_t dac7578_get_ch_val(uint8_t ch_idx) {
    return ACCURATE_DAC.channel_val[ch_idx];
}
/************************************************************************/

/************************************************************************/
/*  i2c communication functions */
// send all channel parameters contained in the structure via i2c 
void dac7578_i2c_send_all_param() {
    uint8_t i = 0;
    uint8_t i2c_glob_wr_buffer[2];

    for (i = 0; i < DAC7578_NCH - 1; i++) {
        Wire.beginTransmission(ACCURATE_DAC.address);
        i2c_glob_wr_buffer[0] = (uint8_t)(DAC7578_WRU_CMD << 4 | i);
        i2c_glob_wr_buffer[1] = (uint8_t)(ACCURATE_DAC.channel_val[i] >> 4); // data msb
        i2c_glob_wr_buffer[2] = (uint8_t)(ACCURATE_DAC.channel_val[i] << 4); // data lsb
        Wire.write(i2c_glob_wr_buffer, DAC_I2C_WR_PCKT_LEN);
        delay(0.1);
        Wire.endTransmission();

    }
}
