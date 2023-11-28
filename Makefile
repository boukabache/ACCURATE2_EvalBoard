VHDL_FILES := $(wildcard *.vhdl)
JSON_FILE := hardware.json
ASC_FILE := $(JSON_FILE:.json=.asc)
BIN_FILE := $(ASC_FILE:.asc=.bin)
O_FILE := $(VHDL_FILES:.vhdl=.o)

all: $(BIN_FILE)

$(JSON_FILE): $(VHDL_FILES)
	@echo "Converting GHDL to JSON"
	@yosys -m ghdl -p 'ghdl $(VHDL_FILES) -e $(TOP_MODULE); synth_ice40 -json $(JSON_FILE)'

$(ASC_FILE): $(JSON_FILE)
	@echo "Run place and route for $<"
	@nextpnr-ice40 --up5k --json $< --pcf up5k.pcf --package sg48 --asc $@

$(BIN_FILE): $(ASC_FILE)
	@echo "Packing to bin for $<"
	@icepack $< $@
	@echo "Removing intermediate files"
	#@rm -f $< $(<:.asc=.json)

prog:
	@iceprog hardware.bin

clean:
	@echo "Removing intermediate files"
	@rm -f $(JSON_FILE) $(ASC_FILE) $(BIN_FILE) $(O_FILE)
