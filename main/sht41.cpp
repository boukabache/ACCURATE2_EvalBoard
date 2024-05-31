/*
 * sht41.cpp
 *
 * Created: 14/09/2024 14:10:08
 *  Author: hliverud
 */

#include "sht41.h"
#include <Arduino.h>
#include <Wire.h>
#include <math.h>

 // CRC-8 polynomial: x^8 + x^5 + x^4 + 1 (0x31)
uint8_t crc8(const uint8_t* data, int len) {
    uint8_t crc = 0xFF;
    for (int j = len; j; --j) {
        crc ^= *data++;
        for (int i = 8; i; --i) {
            crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
        }
    }
    return crc;
}

// Read temperature and humidity from sensor
TempHumMeasurement sht41_i2c_read(void) {
    TempHumMeasurement tempHum = { 0, 0, SHT41_OK };

    Wire.beginTransmission(SHT41_ADDR);
    Wire.write(SHT41_CMD_MEASURE);
    if (Wire.endTransmission() != 0) {
        tempHum.status = SHT41_ERR_I2C;
        return tempHum;
    }

    delay(85);  // Delay for maximum measurement time

    if (Wire.requestFrom(SHT41_ADDR, SHT41_RD_LEN) != SHT41_RD_LEN) {
        tempHum.status = SHT41_ERR_MEASUREMENT;
        return tempHum;
    }

    uint8_t buffer[SHT41_RD_LEN];
    for (int i = 0; i < SHT41_RD_LEN; i++) {
        buffer[i] = Wire.read();
    }

    // Validate CRC
    if (crc8(buffer, 2) != buffer[2] || crc8(buffer + 3, 2) != buffer[5]) {
        tempHum.status = SHT41_ERR_CRC;
        return tempHum;
    }

    uint16_t sht41_temp_u16 = (buffer[0] << 8) | buffer[1];
    uint16_t sht41_rh_u16 = (buffer[3] << 8) | buffer[4];

    // Conversion formulas from SHT41 datasheet
    tempHum.temperature = -45 + 175 * sht41_temp_u16 / (float)(65535);
    tempHum.humidity = -6 + 125 * sht41_rh_u16 / (float)(65535);

    // Crop humidity values to the range of 0% to 100%
    if (tempHum.humidity > 100) tempHum.humidity = 100;
    if (tempHum.humidity < 0) tempHum.humidity = 0;

    return tempHum;
}
