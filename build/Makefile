# Makefile must run after sourcing the oss-cad-suite environment
# in the calling shell.
#
# Makefile must run inside the build directory
# The vhdl files are in the hdl directory
# Directory example:
# project/
# ├─ hdl/
# │  ├─ pkg/
# ├─ submodules/
# ├─ build/
# │  ├─ Makefile


VHDL_FILES := $(wildcard ../hdl/*.vhd) $(wildcard ../hdl/pkg/*.vhd)

JSON_FILE := hardware.json
ASC_FILE := $(JSON_FILE:.json=.asc)
BIN_FILE := $(ASC_FILE:.asc=.bin)
O_FILE := $(VHDL_FILES:.vhd=.o)

# GHDL work directory
WORK_DIR := ./
# GHDL build flags
GHDLFLAGS := --std=08 --workdir=$(WORK_DIR)
# Top module name
TOP_MODULE := TopLevel

all: $(BIN_FILE)

# --no-formal is needed to avoid $assert cell errors
$(JSON_FILE): $(VHDL_FILES)
	@echo "Converting GHDL to JSON"
	yosys -m ghdl -p 'ghdl --no-formal $(GHDLFLAGS) $(VHDL_FILES) -e $(TOP_MODULE); synth_ice40 -dsp -json $(JSON_FILE)'

$(ASC_FILE): $(JSON_FILE)
	@echo "Run place and route for $<"
	nextpnr-ice40 --u4k --package sg48 --json $< --pcf lp4k_wlcs36.pcf --asc $@

$(BIN_FILE): $(ASC_FILE)
	@echo "Packing to bin for $<"
	icepack $< $@

# Works only for flash programming. -S is needed for direct programming
prog:
	@echo "Programming the flash"
	iceprog hardware.bin -v 2>log.txt
	@echo "Done. See log.txt for more details."

# Perform SRAM programming (for directly programming the FPGA)
prog-s:
	@echo "Programming the FPGA SRAM"
	iceprog -S hardware.bin
	@echo "Done"

clean:
	@echo "Removing intermediate files"
	rm -f $(JSON_FILE) $(ASC_FILE) $(BIN_FILE) $(O_FILE)


# Convenience formula that synthesizes, implements and programs the FPGA
all-p: all prog
all-ps: all prog-s

# -g (before -m) is to print also debug messages
show:
	@echo "Converting GHDL to JSON"
	yosys -m ghdl -p 'ghdl --no-formal $(GHDLFLAGS) $(VHDL_FILES) -e $(TOP_MODULE); synth_ice40 -dsp -json $(JSON_FILE); show'


# Run the style check rules over the full VHDL project
.PHONY: styleCheck
styleCheck: ./styleCheck/rules.yaml $(VHDL_FILES)
	vsg -f $(VHDL_FILES) \
		-c ./styleCheck/rules.yaml
#		--junit styleCheck/styleCheck_junit.xml --quality_report styleCheck/styleCheck_quality_report.xml

# Run the style check rules over the specified file
.PHONY: styleCheckFile
styleCheckFile: ./styleCheck/rules.yaml $(FILE_TO_CHECK)
	vsg -f $(FILE_TO_CHECK) \
		-c ./styleCheck/rules.yaml