# Extremely simple makefile.

.PHONY: all clean test-ddr4

all:
	g++ -std=c++0x -Wall -I ../api -I ../api/linux ../api/linux/intel_fpga_pcie_api_linux.cpp intel_fpga_pcie_link_test.cpp -o intel_fpga_pcie_link_test
	g++ -std=c++0x -Wall -I ../api -I ../api/linux ../api/linux/intel_fpga_pcie_api_linux.cpp intel_fpga_pcie_ddr4_test.cpp -o intel_fpga_pcie_ddr4_test
test-ddr4: all
	@for channel in A B C D; do ./intel_fpga_pcie_ddr4_test $$channel || exit $$?; done

clean:
	rm -f ./intel_fpga_pcie_link_test ./intel_fpga_pcie_ddr4_test
