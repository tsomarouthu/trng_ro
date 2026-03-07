TOP_TB     ?= tb/tb_top.sv

EXCLUDE_PATTERNS ?= -not -path "*/tb/*"

RTL_FILES := $(shell \
  find rtl -type f \( -name '*.sv' -o -name '*.v' \) $(EXCLUDE_PATTERNS) | sort \
)

BUILD_DIR  ?= build
VVP_OUT    ?= $(BUILD_DIR)/sim.out
DEFS       ?= -DSIMULATION

.PHONY: all prep sim clean tools list

all: sim

prep:
	@mkdir -p $(BUILD_DIR)

list:
	@echo "RTL_FILES:"; \
	for f in $(RTL_FILES); do echo "  $$f"; done

# Simulation (Icarus)
sim: prep
	iverilog -g2012 $(DEFS) -o $(VVP_OUT) \
    	$(TOP_TB) $(RTL_FILES)
	vvp $(VVP_OUT)

tools:
	sudo apt-get update && sudo apt-get install -y iverilog gtkwave

clean:
	@rm -rf $(BUILD_DIR) waves.vcd