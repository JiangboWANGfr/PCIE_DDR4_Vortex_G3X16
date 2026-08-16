IVERILOG ?= iverilog
VVP ?= vvp
BUILD_DIR ?= /tmp/board_mgmt_sim

MASTER_RTL := board_mgmt_i2c_master.v
CORE_RTL := board_mgmt_i2c_master.v board_mgmt_core.v
SLAVE_MODEL := tb_i2c_slave_model.v

.PHONY: all test test-i2c test-core test-drain test-dynclk test-manager synth-check

all: test

test: test-i2c test-core test-drain test-dynclk test-manager synth-check

test-i2c:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_board_mgmt_i2c_master \
		-o $(BUILD_DIR)/tb_board_mgmt_i2c_master.vvp \
		$(MASTER_RTL) $(SLAVE_MODEL) tb_board_mgmt_i2c_master.v
	$(VVP) $(BUILD_DIR)/tb_board_mgmt_i2c_master.vvp

test-core:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_board_mgmt_core \
		-o $(BUILD_DIR)/tb_board_mgmt_core.vvp \
		$(CORE_RTL) $(SLAVE_MODEL) tb_board_mgmt_core.v
	$(VVP) $(BUILD_DIR)/tb_board_mgmt_core.vvp

test-drain:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_de10pro_vortex_mem_drain \
		-o $(BUILD_DIR)/tb_de10pro_vortex_mem_drain.vvp \
		de10pro_vortex_mem_drain.v tb_de10pro_vortex_mem_drain.v
	$(VVP) $(BUILD_DIR)/tb_de10pro_vortex_mem_drain.vvp

test-dynclk:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_de10pro_dynamic_clock \
		-o $(BUILD_DIR)/tb_de10pro_dynamic_clock.vvp \
		de10pro_dynamic_clock.v tb_de10pro_dynamic_clock.v
	$(VVP) $(BUILD_DIR)/tb_de10pro_dynamic_clock.vvp

test-manager:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_de10pro_board_manager \
		-o $(BUILD_DIR)/tb_de10pro_board_manager.vvp \
		$(CORE_RTL) de10pro_dynamic_clock.v de10pro_board_manager.v \
		tb_de10pro_board_manager.v
	$(VVP) $(BUILD_DIR)/tb_de10pro_board_manager.vvp

synth-check:
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s board_mgmt_core \
		-o $(BUILD_DIR)/board_mgmt_core.vvp $(CORE_RTL)
	$(IVERILOG) -g2012 -Wall -s de10pro_vortex_mem_drain \
		-o $(BUILD_DIR)/de10pro_vortex_mem_drain.vvp \
		de10pro_vortex_mem_drain.v
	$(IVERILOG) -g2012 -Wall -s de10pro_board_manager \
		-o $(BUILD_DIR)/de10pro_board_manager.vvp \
		$(CORE_RTL) de10pro_dynamic_clock.v de10pro_board_manager.v
