/*
 * sht41.cpp
 *
 * Created: 04/03/2021 08:04:48
 *  Author: vcruchet, hliverud
 */ 

#include "sht41.h"
#include <Arduino.h>
#include <Wire.h>

bool sht41_temp_rq		= false;
bool sht41_rh_rq		= false;
bool sht41_start_t		= false;
bool sht41_start_rh		= false;
bool sht41_updated		= true;

uint16_t sht41_temp_u16		= 0;	// raw temperature sensor data
uint16_t sht41_rh_u16		= 0;	// raw relative-humidity sensor data

// get the latest temperature reading
uint16_t sht41_get_temp(void) {
    return sht41_temp_u16;
}

// get the latest humidity reading
uint16_t sht41_get_rh(void) {
    return sht41_rh_u16;
}

// request read temperature sensor via i2c
void sht41_i2c_read_temp(void) {	
    sht41_updated = false;
    sht41_start_t = false;
    
    Wire.beginTransmission(SHT41_ADDR);
    Wire.write(SHT41_CMD_TEMP_H >> 8);
    Wire.write(SHT41_CMD_TEMP_H & 0xFF);
    Wire.endTransmission();
    
    delay(15);
    
    Wire.requestFrom(SHT41_ADDR, SHT41_RD_LEN);
    
    uint8_t buffer[SHT41_RD_LEN];
    buffer[0] = Wire.read();
    buffer[1] = Wire.read();
    buffer[2] = Wire.read();
    
    sht41_temp_u16 = (buffer[0] << 8) | buffer[1];
    
    sht41_temp_rq = true;
    
    //sht41_update_temp();
}

// update temperature from i2c received data
void sht41_update_temp(void) {
    sht41_updated = true;
    
    // conversion formula from SHT41 datasheet
    //sht41_temp_celsius = -46.85 + 175.72 * sht41_temp_u16 / 65536; // in �C
}

// request read humidity (RH) sensor via i2c
void sht41_i2c_read_rh(void) {
    sht41_updated = false;
    sht41_start_rh = false;
    
    Wire.beginTransmission(SHT41_ADDR);
    Wire.write(SHT41_CMD_RH_H >> 8);
    Wire.write(SHT41_CMD_RH_H & 0xFF);
    Wire.endTransmission();
    
    delay(15);
    
    Wire.requestFrom(SHT41_ADDR, SHT41_RD_LEN);
    
    uint8_t buffer[SHT41_RD_LEN];
    buffer[0] = Wire.read();
    buffer[1] = Wire.read();
    buffer[2] = Wire.read();
    
    sht41_rh_u16 = (buffer[0] << 8) | buffer[1];
    
    sht41_rh_rq = true;
    
    //sht41_update_rh();
}

// update rh from i2c received data
void sht41_update_rh(void) {
    sht41_updated = true;
    
    // conversion formula from SHT41 datasheet
    //sht41_rh_percent = -6 + 125 * sht41_rh_u16 / 65536; // in %RH
}
