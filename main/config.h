#ifndef CONFIG_H
#define CONFIG_H

// Uncomment the following line to enable debug mode
// #define DEBUG

// To enable raw output, uncomment the following line:
#define RAW_OUTPUT

// Clock frequency of the ACCURATE frontend
#define ACCURATE_CLK 50E6 // 50 MHz

// Hold display time for the transition screen
#define TRANSITION_TIME 3

// SHT41 Settings
#define SHT41_RD_PERIOD 1 // periodic read interval [s]

// ACCURATE Constants
#define DOWNSCALING_FACTOR 10E14
const float Cf = 5e-12 * DOWNSCALING_FACTOR;

// Default values for the DAC voltage channels, in volts
#define DEFAULT_VOUTA 1.6
#define DEFAULT_VOUTB 1.5
#define DEFAULT_VOUTC 1.55
#define DEFAULT_VOUTD 2.5
#define DEFAULT_VOUTE 1.6
#define DEFAULT_VOUTF 2.5
#define DEFAULT_VOUTG 1.83
#define DEFAULT_VOUTH 1.18


struct CurrentMeasurement {
    float currentInFemtoAmpere; // Current in fA
    float convertedCurrent;     // Converted current based on range
    String range;               // String indicating the current range
};


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

// ADC Settings
#define CURRENT_MEASUREMENT_DELAY 100 // Delay between current measurements [ms]

#endif // CONFIG_H
