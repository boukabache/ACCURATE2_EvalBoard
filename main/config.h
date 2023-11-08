
// IO Settings
#define LED_ALIVE_PIN           PIN_LED_13
#define LED_1_PIN               14
#define LED_2_PIN               15
#define LED_3_PIN               16


// DAC Settings
#define DAC7578_NCH		        8 // number of channels per DAC. Must not exceed 2^8-1 = 255
#define DAC_ADDRESS 	        0b1001011

#define DAC7578_CONV_VOLT(V)    ( (uint16_t)(4096/3 * V) )

// DACs channels
#define VBIAS1_CH		0
#define VCM_CH			1
#define VTH1_CH			2
#define VCHARGEP_CH		3
#define VTH2_CH			4
#define VTH4_CH		 	5
#define VTH3_CH			6
#define VBIAS3_CH		7

/* DACs channel default values
 * calculated from decimal value as:
 *		V_HEX = 4096/3 * V_dec
*/
#define VBIAS1_REG			0x00000889 // 1.6 V --
#define VBIAS3_REG 		 	0x0000064B // 1.18V
#define VCM_REG 			0x00000800 // 1.5V
#define VTH1_REG 			0x00000889 // 1.6V
#define VTH2_REG 			0x00000911 // 1.7V
#define VTH3_REG 			0x000009C3 // 1.83V
#define VTH4_REG 			0x00000D55 // 2.5V
#define VCHARGEP_REG  		0x00000D55 // 2.5V

// SHT41 Settings
#define SHT41_ADDR			    0b1000000
#define SHT41_CMD_TEMP_H	    0b11100011 // measurement command for temperature, hold master
#define SHT41_CMD_TEMP_NH	    0b11110011 // measurement command for temperature, no-hold master
#define SHT41_CMD_RH_H		    0b11100101 // measurement command for relative humidity, hold master
#define SHT41_CMD_RH_NH		    0b11110101 // measurement command for relative humidity, no-hold master
#define SHT41_RD_PERIOD		    1 // periodic read interval [s]
