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

#define FPGA_ADDR 0b0000011


void fpga_init();

float fpga_get_current();

std::vector<float> fpga_get_current_comp();

void fpga_set_reset(bool reset);

void fpga_set_enable(bool high, bool med, bool low);


#endif /* FPGA_H_ */
