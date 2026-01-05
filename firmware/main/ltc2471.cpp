/*
 * ltc2471.cpp
 *
 * Created: 05/06/2024 14:55
 *  Author: hliverud
 */

#include "ltc2471.h"
#include <Arduino.h>

uint16_t ltc2471_read() {
    uint16_t adcValue = 0;

    Wire.beginTransmission(LTC2471_ADDRESS);
    Wire.write(LTC2471_CONFIG); // Write configuration byte to set SPD=1
    if (Wire.endTransmission() != 0) {
        return adcValue;
    }

    while (Wire.requestFrom(LTC2471_ADDRESS, LTC2471_RD_LEN) < LTC2471_RD_LEN) {
    }

    adcValue = (Wire.read() << 8);  // Read MSB
    adcValue |= Wire.read();        // Read LSB

    return adcValue;
}


float ltc2471_read_voltage() {
    uint16_t adcValue = ltc2471_read();
    float voltage = ((float)adcValue);
    return voltage;
}

float ltc2471_read_current() {
    const uint16_t MAX_ADC_VALUE = 65535; // Maximum value for a 16-bit ADC
    uint16_t adcValue1, adcValue2;
    float voltage1, voltage2;
    unsigned long startTime, endTime;
    float deltaT, deltaV, current;

    do {
        // First measurement
        Wire.beginTransmission(LTC2471_ADDRESS);
        Wire.write(LTC2471_CONFIG);
        Wire.endTransmission();
        while (Wire.requestFrom(LTC2471_ADDRESS, LTC2471_RD_LEN) < LTC2471_RD_LEN) {
        }
        startTime = micros();
        adcValue1 = (Wire.read() << 8) | Wire.read();
        voltage1 = (adcValue1 * LTC2471_VREF) / MAX_ADC_VALUE;

        delay(CURRENT_MEASUREMENT_DELAY);

        // Second measurement
        Wire.beginTransmission(LTC2471_ADDRESS);
        Wire.write(LTC2471_CONFIG);
        Wire.endTransmission();
        while (Wire.requestFrom(LTC2471_ADDRESS, LTC2471_RD_LEN) < LTC2471_RD_LEN) {
        }
        endTime = micros();
        adcValue2 = (Wire.read() << 8) | Wire.read();
        voltage2 = (adcValue2 * LTC2471_VREF) / MAX_ADC_VALUE;

        // Check for saturation
    } while (adcValue1 == MAX_ADC_VALUE || adcValue2 == MAX_ADC_VALUE || adcValue1 == 0 || adcValue2 == 0);

    deltaT = (endTime - startTime) / 1000000.0;
    deltaV = voltage2 - voltage1;
    current = (Cf * deltaV) / deltaT;
    return current;
}
