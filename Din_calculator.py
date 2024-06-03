#!/usr/bin/env python

# The Vout voltage of the DAC's channels is determined by the following
# formula:
# Vout = Vref * (D/4096)
# where D is the 12-bit digital ([A-H]xDI) value and Vref is the
# reference voltage.
# 4069 is given by 2^n, where n is the number of bits of the DAC (12-bit).
# In the current Evaluation board design, Vref is 3V.

def main():
    
    # Values are in Volts
    voltage_dict = {
        "A1_Vbias1": 1.6,
        "Vcm": 1.5,
        "A1_Vth1": 1.55,
        "A1_Vcharge+": 2.5,
        "A1_Vth2": 1.6,
        "A1_Vth4": 2.5,
        "A1_Vth3": 1.83,
        "A1_Vbias3": 1.18
    }
    # print(voltage_dict)

    values = list(voltage_dict.values())

    result = [(x * 4096) // 3 for x in values]
    result_with_labels = dict(zip(voltage_dict.keys(), result))
    # print(result_with_labels)

    for key, value in result_with_labels.items():
        print(f"{key}: {value} - ({bin(int(value))[2:].zfill(12)}) - 0x{hex(int(value))[2:].zfill(3)}")

    exit(0)

if __name__ == "__main__":
    main()