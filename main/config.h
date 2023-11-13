
// IO Settings
#define LED_ALIVE_PIN           PIN_LED_13
#define LED_1_PIN               14
#define LED_2_PIN               15
#define LED_3_PIN               16

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
#define SHT41_RD_PERIOD		    1 // periodic read interval [s]
