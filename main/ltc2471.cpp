/*
 * ltc2471.cpp
 *
 * Created: 05/06/2024 14:55
 *  Author: hliverud
 */

#include "LTC2471.h"

 // Function to configure the ADC
void ltc2471_configure() {
    Wire.beginTransmission(LTC2471_ADDRESS);
    Wire.write(0xA0);  // Configuration byte: Enable, SPD=0 (208sps), SLP=0 (Nap mode)
    Wire.endTransmission();
}

// Function to read ADC value
uint16_t ltc2471_read() {
    uint16_t adcValue = 0;

    Wire.beginTransmission(LTC2471_ADDRESS);
    Wire.endTransmission();

    Wire.requestFrom(LTC2471_ADDRESS, 2);  // Request 2 bytes from ADC
    if (Wire.available() == 2) {
        adcValue = Wire.read() << 8;  // Read MSB
        adcValue |= Wire.read();      // Read LSB
    }

    return adcValue;
}

// Function to read ADC value and convert to voltage
float ltc2471_read_voltage() {
    uint16_t adcValue = ltc2471_read();
    return (adcValue / 65535.0) * 1.25;  // Convert ADC value to voltage
}
