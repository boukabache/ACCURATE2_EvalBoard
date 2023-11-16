/*
 * fpga.h
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#ifndef FPGA_H_
#define FPGA_H_

#include <Wire.h>
#include <vector>

#define FPGA_ADDR 0b0000011 // I2C address

 // Command addresses
#define CMD_MEASUREMENT_TIME 0x01
#define CMD_TIMINGS 0x02
#define CMD_CPCHARGE 0x03
#define CMD_EXTRACONFIG 0x04
#define CMD_REGISTER_SIGNAL 0x05

// Struct to hold the data read from the FPGA
struct FPGAData {
    uint32_t timer; // 32-bit timer value
    uint64_t amount_of_charge; // 52-bit amount of charge
    uint64_t cp[3]; // 3x 52-bit cp values
};

// Function to send an 8-bit measurement time to the FPGA
void send_measurement_time(uint8_t measurement_time);

// Function to send 2x 8-bit timings to the FPGA
void send_timings(uint8_t* timings, uint8_t len);

// Function to send 3x 24-bit cpCharge values to the FPGA
void send_cpCharge(uint8_t* cpCharge, uint8_t len);

// Function to send a 96-bit + 4-bit extraConfig value to the FPGA
void send_extraConfig(uint8_t* extraConfig, uint8_t len);

// Function to send a register signal to the FPGA
void send_register_signal(uint8_t register_signal);

// Function to read data from the FPGA
FPGAData fpga_read_all();

#endif /* FPGA_H_ */