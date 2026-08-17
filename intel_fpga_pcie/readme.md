测试流程：

# 1. 加载 Intel 配套驱动

  cd intel_fpga_pcie/kernel/linux
  sudo ./load

# 2. 编译并测试四路 DDR4

  cd ../../user/example
  make test-ddr4

  只测试单路：

  ./intel_fpga_pcie_ddr4_test A
  ./intel_fpga_pcie_ddr4_test B
  ./intel_fpga_pcie_ddr4_test C
  ./intel_fpga_pcie_ddr4_test D

  如果重新烧写 SOF 后第一次 DMA 超时，建议重启主机，让 PCIe 端点重新干净枚举，然后再加载驱动测试。本次就是重启后四路全部通过。

  PCIe_SW_KIT 仍有用，但用途不同：

- intel_fpga_pcie

  - 使用 /dev/intel_fpga_pcie_drv
  - 用于当前 SOF 的 PCIe DMA、四路 DDR4 硬件验证
  - 当前测试应优先使用它
- PCIe_SW_KIT

  - 旧 Terasic 软件栈，使用 /dev/altera_pcie0 和 PCIE_Open
  - 主要用于依赖 Terasic API 的旧示例或 Vortex 运行时
  - 默认设备 ID 是 0xE003，而当前 FPGA 是 1172:0000，默认配置不能直接绑定，必须把 device_id 改为 0x0000
  - 不要与 intel_fpga_pcie_drv 同时加载
