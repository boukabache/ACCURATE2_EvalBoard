/*
 * fpga.cpp
 *
 * Created: 11/13/2023 13:40
 *  Author: hliverud
 */

#include "fpga.h"
#include <Wire.h>
#include <Math.h>

FPGAData set_FPGAData() {
    FPGAData fpgaData;

    fpgaData.accurate.tCharge = AccurateTCharge;
    fpgaData.accurate.tInjection = AccurateTInjection;
    fpgaData.accurate.disableCP1 = AccurateDisableCP1;
    fpgaData.accurate.disableCP2 = AccurateDisableCP2;
    fpgaData.accurate.disableCP3 = AccurateDisableCP3;

    fpgaData.accurate.singlyCPActivation = AccurateSinglyCPActivation;
    fpgaData.accurate.cooldownMinCP1 = AccurateCooldownMin_vTh2;
    fpgaData.accurate.cooldownMaxCP1 = AccurateCooldownMax_vTh2;
    fpgaData.accurate.cooldownMinCP2 = AccurateCooldownMin_vTh3;
    fpgaData.accurate.cooldownMaxCP2 = AccurateCooldownMax_vTh3;
    fpgaData.accurate.cooldownMinCP3 = AccurateCooldownMin_vTh4;
    fpgaData.accurate.cooldownMaxCP3 = AccurateCooldownMax_vTh4;

    double CCrome = CInt;
    double C1 = AccurateCcp1;
    double C2 = AccurateCcp2;
    double C3 = AccurateCcp3;

    fpgaData.accurate.chargeQuantaCP1 = (int)(C1 * (VP - VM) / CCrome * pow(2, 24) / (2 * VRANGE));
    fpgaData.accurate.chargeQuantaCP2 = (int)(C2 * (VP - VM) / CCrome * pow(2, 24) / (2 * VRANGE));
    fpgaData.accurate.chargeQuantaCP3 = (int)(C3 * (VP - VM) / CCrome * pow(2, 24) / (2 * VRANGE));

    fpgaData.accurateCapEnable = AccurateCapEnable;
    fpgaData.accurateVCm = (int)ACCURATE_V_CM;
    fpgaData.accurateVTh1 = (int)ACCURATE_V_TH1;
    fpgaData.accurateVTh2 = (int)ACCURATE_V_TH2;
    fpgaData.accurateVTh3 = (int)ACCURATE_V_TH3;
    fpgaData.accurateVTh4 = (int)ACCURATE_V_TH4;
    fpgaData.accurateVBias1 = (int)ACCURATE_V_BIAS1;
    fpgaData.accurateVBias3 = (int)ACCURATE_V_BIAS3;
    fpgaData.accurateVChargeP = (int)ACCURATE_V_CHARGE_P;

    return fpgaData;
}

void write_FPGAData(FPGAData fpgaData) {
    Wire.beginTransmission(FPGA_I2C_ADDRESS);
    Wire.write((uint8_t*)&fpgaData, sizeof(FPGAData));
    Wire.endTransmission();
}

// Function to receive data from the FPGA
FPGAData receive_data() {
    FPGAData data;

    // Request data from the FPGA
    Wire.requestFrom(FPGA_I2C_ADDRESS, sizeof(FPGAData));

    // Read the data into the FPGAData struct
    Wire.readBytes((char*)&data, sizeof(FPGAData));

    return data;
}
