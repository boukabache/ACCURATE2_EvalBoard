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

#define FPGA_I2C_ADDRESS            0b0000011 // I2C address

 // Command addresses
#define CMD_MEASUREMENT_TIME        0x01
#define CMD_TIMINGS                 0x02
#define CMD_CPCHARGE                0x03
#define CMD_EXTRACONFIG             0x04
#define CMD_REGISTER_SIGNAL         0x05

#define VP                          2.5
#define VM                          1.5
#define VRANGE                      3.3
#define ACCURATE_V_CM               1.5 * 4096.0/3.0
#define ACCURATE_V_TH1              1.55* 4096.0/3.0
#define ACCURATE_V_TH2              1.6 * 4096.0/3.0
#define ACCURATE_V_TH3              1.83* 4096.0/3.0
#define ACCURATE_V_TH4              2.5 * 4096.0/3.0
#define ACCURATE_V_BIAS1            1.6 * 4096.0/3.0
#define ACCURATE_V_BIAS3            1.18* 4096.0/3.0
#define ACCURATE_V_CHARGE_P         2.5 * 4096.0/3.0

#define AccurateCcp1                500e-15
#define AccurateCcp2                1e-12
#define AccurateCcp3                4e-12
#define DetType                     0
#define AccurateTCharge             7
#define AccurateTInjection          8
#define AccurateCapEnable           0
#define AccurateDisableCP1          0
#define AccurateDisableCP2          0
#define AccurateDisableCP3          0
#define AccurateSinglyCPActivation  0
#define AccurateCooldownMin_vTh2    0
#define AccurateCooldownMax_vTh2    0
#define AccurateCooldownMin_vTh3    0
#define AccurateCooldownMax_vTh3    0
#define AccurateCooldownMin_vTh4    0
#define AccurateCooldownMax_vTh4    0
#define CInt                        100.0e-12

struct FPGAData {
    uint32_t timer; // 32-bit timer value
    uint64_t amount_of_charge; // 52-bit amount of charge

    // PL to PS interface
    int64_t meas100ms; // Current measurement: The temperate compensated voltage over one 100ms window

    // PS to PL interface
    uint32_t measurementTime; // Measurement time entered as a number of 100ms periods
    uint16_t accurateVCm; // Common mode voltage in DAC7578 LSB
    uint16_t accurateVTh1; // Threshold voltage 1 in DAC7578 LSB
    uint16_t accurateVTh2; // Threshold voltage 2 in DAC7578 LSB
    uint16_t accurateVTh3; // Threshold voltage 3 in DAC7578 LSB
    uint16_t accurateVTh4; // Threshold voltage 4 in DAC7578 LSB
    uint16_t accurateVBias1; // Voltage bias1 in DAC7578 LSB
    uint16_t accurateVBias3; // Voltage bias3 in DAC7578 LSB
    uint16_t accurateVChargeP; // Reference voltage that will charge the charge pumps capacitors on the positive side in DAC7578 LSB
    bool accurateCapEnable; // Activates the additional input capacitance

    struct Accurate {
        uint8_t tCharge; // Time duration in clock cycles for recharge of the charge pump
        uint8_t tInjection; // Time duration in clock cycles for activation (injection) of the charge pump
        int32_t chargeQuantaCP1; // Charge injected by one activation of CP1
        int32_t chargeQuantaCP2; // Charge injected by one activation of CP2
        int32_t chargeQuantaCP3; // Charge injected by one activation of CP3
        bool disableCP1; // Do not use first charge pump
        bool disableCP2; // Do not use second charge pump
        bool disableCP3; // Do not use third charge pump
        bool singlyCPActivation; // Activate only one charge pump at a time
        uint16_t cooldownMinCP1; // Minimum cooldown time for CP1 in clock cycles
        uint16_t cooldownMaxCP1; // Maximum cooldown time for CP1 in clock cycles
        uint16_t cooldownMinCP2; // Minimum cooldown time for CP2 in clock cycles
        uint16_t cooldownMaxCP2; // Maximum cooldown time for CP2 in clock cycles
        uint16_t cooldownMinCP3; // Minimum cooldown time for CP3 in clock cycles
        uint16_t cooldownMaxCP3; // Maximum cooldown time for CP3 in clock cycles
    } accurate;
};

void write_FPGAData(FPGAData fpgaData);

FPGAData set_FPGAData();

// Function to read data from the FPGA
FPGAData receive_data();

#endif /* FPGA_H_ */
