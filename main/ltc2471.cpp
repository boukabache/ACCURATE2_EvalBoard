/*
 * ltc2471.cpp
 *
 * Created: 05/06/2024 14:55
 *  Author: hliverud
 */

#include "LTC2471.h"
#include <Arduino.h>

uint16_t ltc2471_read() {
    uint16_t adcValue = 0;

    Wire.beginTransmission(LTC2471_ADDRESS);
    if (Wire.endTransmission() != 0) {
        return adcValue;
    }

    delay(10);

    Wire.requestFrom(LTC2471_ADDRESS, LTC2471_RD_LEN);
    if (Wire.available() == 2) {
        adcValue = (Wire.read() << 8);  // Read MSB
        adcValue |= Wire.read();        // Read LSB
        Serial.println(adcValue);
    }

    return adcValue;
}


float ltc2471_read_voltage() {
    uint16_t adcValue = ltc2471_read();
    // Convert ADC value to voltage
    float voltage = (adcValue * LTC2471_VREF) / LTC2471_RESOLUTION;
    return voltage;
}
