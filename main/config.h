#ifndef CONFIG_H
#define CONFIG_H

// IO Settings
#define LED_ALIVE_PIN           PIN_LED_13
#define LED_1_PIN               14
#define LED_2_PIN               15
#define LED_3_PIN               16

// SHT41 Settings
#define SHT41_RD_PERIOD		    1 // periodic read interval [s]

// DAC Settings
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

#endif // CONFIG_H
