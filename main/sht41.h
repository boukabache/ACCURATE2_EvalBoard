/*
 * sht41.h
 *
 * Created: 04/03/2021 08:04:32
 *  Author: vcruchet
 *	Description: Parameters and functions related to the temperature and humidity sensor.
 *		I2C communication functions allow the MCU to read temperature and humidity according
 *		to the datasheet specifications. The *"hold"* verison of the command are used,
 *		what implies that the I2C bus is busy during the measurement time (max 85ms).
 */
#include <stdint.h>
#include <stdbool.h>

#ifndef SHT41_H_
#define SHT41_H_

#define SHT41_RD_LEN        1
#define SHT41_ADDR			0x44        // SHT41 I2C address
#define SHT41_CMD_TEMP_H	0b11100011 // measurement command for temperature, hold master
#define SHT41_CMD_TEMP_NH	0b11110011 // measurement command for temperature, no-hold master
#define SHT41_CMD_RH_H		0b11100101 // measurement command for relative humidity, hold master
#define SHT41_CMD_RH_NH		0b11110101 // measurement command for relative humidity, no-hold master
#define SHT41_RD_PERIOD		1           // periodic read interval [s]

 // global flag to notify a temperature read request
extern bool sht41_rh_rq;
extern bool sht41_temp_rq;
extern bool sht41_start_t;
extern bool sht41_start_rh;
extern bool sht41_updated;

// request read temperature sensor via i2c
void sht41_i2c_read_temp(void);
// update temperature register
void sht41_update_temp(void);
// get the latest temperature reading
uint16_t sht41_get_temp(void);

// request read humidity (RH) sensor via i2c
void sht41_i2c_read_rh(void);
// update humidity register
void sht41_update_rh(void);
// get the latest humidity reading
uint16_t sht41_get_rh(void);

#endif /* T_SENSOR_H_ */