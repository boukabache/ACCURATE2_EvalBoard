/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"

void fpga_init() {

}

float fpga_get_current() {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(FPGA_ADDR);
    Wire.endTransmission();
    Wire.requestFrom(FPGA_ADDR, 2);
    uint16_t current = Wire.read() << 8;
    current |= Wire.read();
    return current;
}

std::vector<float> fpga_get_current_comp() {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(FPGA_ADDR);
    Wire.endTransmission();
    Wire.requestFrom(FPGA_ADDR, 8);
    uint16_t current_comp1 = Wire.read() << 8;
    current_comp1 |= Wire.read();
    uint16_t current_comp2 = Wire.read() << 8;
    current_comp2 |= Wire.read();
    uint16_t current_comp3 = Wire.read() << 8;
    current_comp3 |= Wire.read();
    uint16_t current_comp4 = Wire.read() << 8;
    current_comp4 |= Wire.read();
    return std::vector<float>{static_cast<float>(current_comp1), static_cast<float>(current_comp2), static_cast<float>(current_comp3), static_cast<float>(current_comp4)};
}

void fpga_set_reset(bool reset) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(reset);
    Wire.endTransmission();
}

void fpga_set_enable(bool high, bool med, bool low) {
    Wire.beginTransmission(FPGA_ADDR);
    Wire.write(high);
    Wire.write(med);
    Wire.write(low);
    Wire.endTransmission();
}
