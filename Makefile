VHDL_FILES := $(wildcard *.vhdl)
JSON_FILE := final.json
ASC_FILE := $(JSON_FILE:.json=.asc)
BIN_FILE := $(ASC_FILE:.asc=.bin)

# Specify the top module for the top.vhdl
TOP_MODULE := top

all: $(BIN_FILE)

$(JSON_FILE): $(VHDL_FILES)
	@echo "Converting GHDL to JSON"
	@if [ "$(VHDL_FILES)" = "$(TOP_MODULE).vhdl" ]; then \
		yosys -m ghdl -p 'ghdl $(TOP_MODULE).vhdl -e top; write_json $@'; \
	else \
		yosys -m ghdl -p 'ghdl $(VHDL_FILES) -e; write_json $@'; \
	fi

$(ASC_FILE): $(JSON_FILE)
	@echo "Run place and route for $<"
	@nextpnr-ice40 --up5k --json $< --pcf up5k.pcf --package sg48 --asc $@

$(BIN_FILE): $(ASC_FILE)
	@echo "Packing to bin for $<"
	@icepack $< $@
	@echo "Removing intermediate files"
	@rm -f $< $(<:.asc=.json)

prog:
	@iceprog final.bin

clean:
	@echo "Removing intermediate files"
	@rm -f $(JSON_FILE) $(ASC_FILE) $(BIN_FILE)
