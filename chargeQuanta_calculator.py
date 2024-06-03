#!/usr/bin/env python

# Values that depends on CROME
Vp = 2.5
Vm = 1.5
CCrome = 100e-12 # 100 pF
Vrange = 3.3

# Values that depends on the chare pumps
C1 = 500e-15
C2 = 1e-12
C3 = 4e-12

middle_step = (Vp-Vm)/CCrome * pow(2,24)/(2*Vrange)

# End results
C1_result = C1 * middle_step
C2_result = C2 * middle_step
C3_result = C3 * middle_step

print(f"C1: {C1_result} - ({bin(int(C1_result))[2:].zfill(24)}) - 0x{hex(int(C1_result))[2:].zfill(6)}")
print(f"C2: {C2_result} - ({bin(int(C2_result))[2:].zfill(24)}) - 0x{hex(int(C2_result))[2:].zfill(6)}")
print(f"C3: {C3_result} - ({bin(int(C3_result))[2:].zfill(24)}) - 0x{hex(int(C3_result))[2:].zfill(6)}")