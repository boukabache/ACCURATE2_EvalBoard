/*
 * fpga.h
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#ifndef FPGA_H_
#define FPGA_H_

#include <Arduino.h>

#define DOWNSCALING_FACTOR 10E14

const float CLOCK_PERIOD = 1E8; // ^-1
const float TW = 0.1;

const float VBIAS1_DEC = 1.6;
const float VBIAS2_DEC = 2.5;
const float VBIAS3_DEC = 1.18;
const float VCM_DEC = 1.5;
const float VTH1_DEC = 1.55;
const float VTH2_DEC = 1.7;
const float VTH3_DEC = 1.83;
const float VTH4_DEC = 2.5;
const float VTH5_DEC = 1.5; // Vcmd
const float VTH6_DEC = 1.5; // Vcharge-
const float VTH7_DEC = 2.5; // Vcharge+

const uint32_t ADC_RESOLUTION_ACCURATE = 4096;
const float REF_VOLTAGE = 3.0;

const float Cf = 5e-12 * DOWNSCALING_FACTOR;
const float Tw = 0.1;

const float VINT1 = (VTH2_DEC - VTH1_DEC) * 0.9;

const float C1 = 454e-15 * DOWNSCALING_FACTOR;
const float C2 = 1060e-15 * DOWNSCALING_FACTOR;
const float C3 = 3950e-15 * DOWNSCALING_FACTOR;

const float Qref1 = C1 * (VTH7_DEC - VTH6_DEC);
const float Qref2 = C2 * (VTH7_DEC - VTH6_DEC);
const float Qref3 = C3 * (VTH7_DEC - VTH6_DEC);

const uint32_t INIT_CONFIG_ADDRESS = 0x01;
const uint32_t GATE_LENGTH_ADDRESS = 0x02;
const uint32_t RST_DURATION_ADDRESS = 0x03;
const uint32_t VBIAS1_ADDRESS = 0x04;
const uint32_t VBIAS2_ADDRESS = 0x05;
const uint32_t VBIAS3_ADDRESS = 0x06;
const uint32_t VCM_ADDRESS = 0x07;
const uint32_t VCM1_ADDRESS = 0x08;
const uint32_t VTH1_ADDRESS = 0x09;
const uint32_t VTH2_ADDRESS = 0x0A;
const uint32_t VTH3_ADDRESS = 0x0B;
const uint32_t VTH4_ADDRESS = 0x0C;
const uint32_t VTH5_ADDRESS = 0x0D;
const uint32_t VTH6_ADDRESS = 0x0E;
const uint32_t VTH7_ADDRESS = 0x0F;

const uint32_t INIT_CONFIG = 0x4107;
const uint32_t RST_DURATION = 0x0708;
const uint32_t INIT_CONFIG_START = 0x01C007;

void readFPGA();

uint32_t readUInt32();

float calculateCurrent(uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3, uint32_t data4);

void attemptResynchronization();

void sendConfigurations();

uint32_t convertVoltageToDAC(float voltage);

void sendParam(uint32_t address, uint32_t value);

uint32_t calculateGateLength();

void printCurrentInAppropriateUnit(float currentInFemtoAmperes);

#endif /* FPGA_H_ */
