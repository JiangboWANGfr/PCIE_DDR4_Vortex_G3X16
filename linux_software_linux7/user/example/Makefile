# Extremely simple makefile.

all:
	g++ -std=c++0x -Wall -I ../api -I ../api/linux ../api/linux/intel_fpga_pcie_api_linux.cpp intel_fpga_pcie_link_test.cpp -o intel_fpga_pcie_link_test
	g++ -std=c++0x -Wall -I ../api -I ../api/linux ../api/linux/intel_fpga_pcie_api_linux.cpp intel_fpga_pcie_ddr4_test.cpp -o intel_fpga_pcie_ddr4_test
clean:
	rm -f ./intel_fpga_pcie_link_test ./intel_fpga_pcie_ddr4_test
