/*
 * sht41.h
 *
 * Created: 14/09/2024 14:10:08
 *  Author: hliverud
 *  Description: Parameters and functions related to the temperature and humidity sensor.
 *  I2C communication functions allow the MCU to read temperature and humidity according
 *  to the datasheet specifications.
 */

#ifndef SHT41_H_
#define SHT41_H_

#include <stdint.h>
#include <stdbool.h>

#define SHT41_RD_LEN        6
#define SHT41_ADDR          0x44 // SHT41 I2C address
#define SHT41_CMD_MEASURE   0xFD // measurement command for temperature, high precision
#define SHT41_RD_PERIOD     1    // periodic read interval [s]

typedef enum {
    SHT41_OK = 0,
    SHT41_ERR_I2C = 1,
    SHT41_ERR_CRC = 2,
    SHT41_ERR_MEASUREMENT = 3
} SHT41_Status;


struct TempHumMeasurement {
    float temperature;          // Temperature in C
    float humidity;             // Humidity in %
    SHT41_Status status;        // Error status
};

// Read temperature and humidity temperature
TempHumMeasurement sht41_i2c_read(void);

// Calculate temperature and humidity from raw data
void sht41_calculate(uint16_t rawTemperature, uint16_t rawHumidity, TempHumMeasurement* measurement);

// CRC calculation
uint8_t crc8(const uint8_t* data, int len);

#endif /* SHT41_H_ */
