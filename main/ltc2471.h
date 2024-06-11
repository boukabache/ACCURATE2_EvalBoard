/*
 * ltc2471.h
 *
 * Created: 05/06/2024 14:55
 *  Author: hliverud
 */


#ifndef LTC2471_H
#define LTC2471_H

#include <Arduino.h>
#include <Wire.h>

 // I2C address for LTC2471 with A0 tied to GND
#define LTC2471_ADDRESS 0x14 // Adjust according to A0 pin configuration (0x14 or 0x54)

#define LTC2471_VREF 1.25  // Internal reference voltage is 1.25V
#define LTC2471_RESOLUTION 65535  // 16-bit ADC resolution
#define LTC2471_RD_LEN 2

uint16_t ltc2471_read();
float ltc2471_read_voltage();

#endif
