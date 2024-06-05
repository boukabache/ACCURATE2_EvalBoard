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

 // I2C address for LTC2471 or LTC2473
#define LTC2471_ADDRESS 0x14 // Adjust according to A0 pin configuration (0x14 or 0x54)

void ltc2471_configure();
uint16_t ltc2471_read();
float ltc2471_read_voltage();

#endif
