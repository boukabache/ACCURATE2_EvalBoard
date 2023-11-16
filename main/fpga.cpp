/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"
#include <Wire.h>

FPGAData fpga_read_all() {
    FPGAData data;
    uint8_t buffer[24]; // Adjust the size of the buffer according to the size of the data you want to read

    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(0); // Replace with the register address
    Wire.endTransmission();
    Wire.requestFrom(FPGA_ADDR, sizeof(buffer));

    for (uint8_t i = 0; i < sizeof(buffer); i++) {
        buffer[i] = Wire.read();
    }

    // Separate the data into their own variables extract timer
    data.timer = ((uint32_t)buffer[0] << 24) |
        ((uint32_t)buffer[1] << 16) |
        ((uint32_t)buffer[2] << 8) |
        buffer[3];

    // Extract amount_of_charge
    data.amount_of_charge = ((uint64_t)buffer[4] << 44) |
        ((uint64_t)buffer[5] << 36) |
        ((uint64_t)buffer[6] << 28) |
        ((uint64_t)buffer[7] << 20) |
        ((uint32_t)buffer[8] << 12) |
        ((uint32_t)buffer[9] << 4) |
        (buffer[10] >> 4);

    // Extract cp
    for (int i = 0; i < 3; i++) {
        data.cp[i] = ((uint64_t)buffer[11 + i * 6] << 44) |
            ((uint64_t)buffer[12 + i * 6] << 36) |
            ((uint64_t)buffer[13 + i * 6] << 28) |
            ((uint64_t)buffer[14 + i * 6] << 20) |
            ((uint32_t)buffer[15 + i * 6] << 12) |
            ((uint32_t)buffer[16 + i * 6] << 4) |
            (buffer[17 + i * 6] >> 4);
    }

    return data;
}

void send_measurement_time(uint8_t measurement_time) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(CMD_MEASUREMENT_TIME);
    Wire.write(measurement_time);
    Wire.endTransmission();
}

void send_timings(uint8_t* timings, uint8_t len) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(CMD_TIMINGS);
    for (uint8_t i = 0; i < len; i++) {
        Wire.write(timings[i]);
    }
    Wire.endTransmission();
}

void send_cpCharge(uint8_t* cpCharge, uint8_t len) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(CMD_CPCHARGE);
    for (uint8_t i = 0; i < len; i++) {
        Wire.write(cpCharge[i]);
    }
    Wire.endTransmission();
}

void send_extraConfig(uint8_t* extraConfig, uint8_t len) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(CMD_EXTRACONFIG);
    for (uint8_t i = 0; i < len; i++) {
        Wire.write(extraConfig[i]);
    }
    Wire.endTransmission();
}

void send_register_signal(uint8_t register_signal) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(CMD_REGISTER_SIGNAL);
    Wire.write(register_signal);
    Wire.endTransmission();
}
