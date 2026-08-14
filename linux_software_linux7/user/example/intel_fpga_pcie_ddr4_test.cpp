#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <sys/mman.h>

#include "intel_fpga_pcie_api.hpp"

namespace {

const uint64_t kDdr4Base = 0x800000000ULL;
const uint64_t kDriverEndpointBias = 0x10000ULL;
const uint64_t kDdr4EndpointOffset = kDdr4Base - kDriverEndpointBias;
const unsigned int kTransferBytes = 4096;

uint32_t test_pattern(unsigned int index)
{
    uint32_t value = 0x9e3779b9U * (index + 1U);
    return value ^ (value >> 16) ^ 0xa5a55a5aU;
}

double mib_per_second(unsigned int bytes, unsigned int microseconds)
{
    if (microseconds == 0)
        return 0.0;
    return static_cast<double>(bytes) * 1000000.0 /
           (static_cast<double>(microseconds) * 1024.0 * 1024.0);
}

} // namespace

int main()
{
    try {
        intel_fpga_pcie_dev dev(0, -1);

        if (!dev.set_kmem_size(kTransferBytes)) {
            std::cerr << "Failed to allocate DMA kernel memory\n";
            return 1;
        }

        void *mapping = dev.kmem_mmap(kTransferBytes, 0);
        if (mapping == MAP_FAILED) {
            std::cerr << "Failed to map DMA kernel memory\n";
            return 1;
        }

        uint32_t *words = static_cast<uint32_t *>(mapping);
        const unsigned int word_count = kTransferBytes / sizeof(*words);
        for (unsigned int i = 0; i < word_count; ++i)
            words[i] = test_pattern(i);

        std::cout << "DDR4 DMA smoke test\n"
                  << "  FPGA address: 0x" << std::hex << kDdr4Base << std::dec << "\n"
                  << "  Transfer:     " << kTransferBytes << " bytes\n";

        if (!dev.dma_queue_write(kDdr4EndpointOffset, kTransferBytes, 0) ||
            !dev.dma_send_write()) {
            std::cerr << "Host-to-DDR4 DMA failed\n";
            dev.kmem_munmap(mapping, kTransferBytes);
            return 1;
        }
        const unsigned int write_us = dev.get_ktimer();

        std::memset(mapping, 0, kTransferBytes);

        if (!dev.dma_queue_read(kDdr4EndpointOffset, kTransferBytes, 0) ||
            !dev.dma_send_read()) {
            std::cerr << "DDR4-to-host DMA failed\n";
            dev.kmem_munmap(mapping, kTransferBytes);
            return 1;
        }
        const unsigned int read_us = dev.get_ktimer();

        unsigned int mismatch_count = 0;
        for (unsigned int i = 0; i < word_count; ++i) {
            const uint32_t expected = test_pattern(i);
            if (words[i] != expected) {
                if (mismatch_count < 8) {
                    std::cerr << "Mismatch at byte 0x" << std::hex
                              << (i * sizeof(*words)) << ": expected 0x"
                              << expected << ", got 0x" << words[i]
                              << std::dec << "\n";
                }
                ++mismatch_count;
            }
        }

        dev.kmem_munmap(mapping, kTransferBytes);

        std::cout << std::fixed << std::setprecision(2)
                  << "  Host -> DDR4: " << write_us << " us, "
                  << mib_per_second(kTransferBytes, write_us) << " MiB/s\n"
                  << "  DDR4 -> Host: " << read_us << " us, "
                  << mib_per_second(kTransferBytes, read_us) << " MiB/s\n";

        if (mismatch_count != 0) {
            std::cerr << "FAIL: " << mismatch_count << " mismatched dwords\n";
            return 1;
        }

        std::cout << "PASS: all " << word_count << " dwords matched\n";
        return 0;
    } catch (const std::exception &ex) {
        std::cerr << "DDR4 DMA test error: " << ex.what() << "\n";
        return 1;
    }
}
