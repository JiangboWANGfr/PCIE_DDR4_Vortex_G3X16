# Board management RTL

This directory contains the DE10-Pro board-management block and its Platform
Designer component. `de10pro_board_manager` wraps the sensor engine with the
versioned BAR0 telemetry ABI and the safe Vortex dynamic-clock sequencer.

## Interfaces

`board_mgmt_core` uses a 50 MHz clock by default and exposes three independent
open-drain I2C buses:

- `temp_scl/temp_sda`: TMP441 temperature monitor
- `fan_scl/fan_sda`: MAX6651 fan controller
- `power_scl/power_sda`: two LTC2945 power monitors on one bus

The I2C pins only drive low or high impedance. Board-level pull-ups are
required.

The Avalon-MM slave is synchronous and never inserts wait states. `avs_address`
is a word address. A read request produces `avs_readdatavalid` and registered
data on the next rising clock edge. Writes to the control register are pulses.

The atomic snapshot is also available without Avalon through
`snapshot_update`, `snapshot_sequence`, `snapshot_valid`, temperature,
TACH0/1, and input/core power outputs. `snapshot_update` pulses for one cycle
when all snapshot outputs are committed. `fan_state_valid`, `fan_full_on`, `fan_full_off`, and `fan_dac` expose whether a control state has been acknowledged and its last
confirmed value. `fan_control_mode`, `fan_control_dac`, and
`fan_control_update` select automatic, forced-full, manual-DAC, or forced-off operation.

## Device initialization and polling

| Device | 7-bit address | Operation |
| --- | ---: | --- |
| TMP441 | `0x1c` | Separate one-byte reads of local `0x00` and remote `0x01` |
| MAX6651 | `0x48` | Write CONFIG `0x02`, DAC `0x06`, and COUNT `0x16 = 0x01`; read TACH0 `0x0c` and TACH1 `0x0e` |
| LTC2945 input | `0x6a` | Write CONTROL `0x00 = 0x05`; read sense `0x14`, VIN `0x1e`, and power `0x05` |
| LTC2945 core | `0x6d` | Write CONTROL `0x00 = 0x05`; read sense `0x14`, VIN `0x1e`, and power `0x05` |

The first fan-bus command after reset is always MAX6651 CONFIG `0x02 = 0x0a`.
If it is NACKed, COUNT and tachometer accesses are skipped until CONFIG
succeeds. The controller starts fail-safe and keeps the first complete poll
round at full speed. Later clean rounds apply this hysteretic policy to the
TMP441 remote temperature:

- below 55 degrees C: write DAC `0x06 = 0x20`, then write open-loop CONFIG
  `0x02 = 0x3a`
- 55 through 59 degrees C: keep the previously confirmed mode
- 60 degrees C or above: write full-on CONFIG `0x02 = 0x0a`

The reduced-mode CONFIG write is never issued unless the preceding DAC write
was acknowledged. A failed I2C transaction or invalid temperature read latches
fail-safe mode.
The controller writes full-on CONFIG at the end of that round and retries until
the write is acknowledged. It remains full-on through the next complete poll
and exits fail-safe only after all temperature, fan, and both power-monitor
transactions in that round succeed.

The default startup delay is 50 ms. The integrated wrapper polls every 100 ms
so a benchmark can collect enough distinct LTC2945 conversion samples.
All readings from one poll round are first stored in shadow registers and then
committed together. Software can read the sequence register, read telemetry,
and read the sequence again; it retries if the two sequence values differ.

The addresses and initialization values match the Terasic demonstration code
under `demo_ref/NIOS_BASIC_DEMO/software/DE10_Pro/`, notably `Fan.c`,
`LTC2945.c`, and `main.c`.

## CSR map

| Word | Byte | Name | Contents |
| ---: | ---: | --- | --- |
| `0x0` | `0x00` | ID | `0x424d4754` (`BMGT`) |
| `0x1` | `0x04` | VERSION | major 1, minor 1, 3 buses, 5 devices |
| `0x2` | `0x08` | STATUS | valid bitmap `[24:16]`; bus busy `[10:8]`; snapshot valid bit 5; configuration/startup/running `[4:0]` |
| `0x3` | `0x0c` | SEQUENCE | increments after each atomic snapshot commit |
| `0x4` | `0x10` | TEMPERATURE | remote byte `[15:8]`, local byte `[7:0]` |
| `0x5` | `0x14` | TACH | TACH1 `[15:8]`, TACH0 `[7:0]` |
| `0x6` | `0x18` | INPUT_SENSE | raw big-endian 16-bit value |
| `0x7` | `0x1c` | INPUT_VIN | raw big-endian 16-bit value |
| `0x8` | `0x20` | INPUT_POWER | raw big-endian 24-bit value |
| `0x9` | `0x24` | CORE_SENSE | raw big-endian 16-bit value |
| `0xa` | `0x28` | CORE_VIN | raw big-endian 16-bit value |
| `0xb` | `0x2c` | CORE_POWER | raw big-endian 24-bit value |
| `0xc` | `0x30` | ERROR | count `[15:0]`, last step low bits `[19:16]`, bus `[21:20]`, NACK/timeout/stuck/short `[25:22]`, sticky buses `[28:26]`, last step high bit 29, unacknowledged byte `[31:30]` |
| `0xe` | `0x38` | SCHEDULER | step low `[3:0]`, bus `[5:4]`, recovery sticky `[10:8]`, step high bit 11, fan mode `[13:12]`, CONFIG `[21:14]`, DAC `[29:22]`, fail-safe bit 30, round-fault bit 31 |
| `0xf` | `0x3c` | CONTROL | write-one pulse: clear sticky/error bit 0, force poll bit 1 |

The STATUS valid bitmap uses bit 0 for temperature, bits 1-2 for TACH0/1,
bits 3-5 for input sense/VIN/power, and bits 6-8 for core sense/VIN/power.
Fan mode is 0 for unknown, 1 for confirmed full-on, 2 for confirmed
reduced open-loop operation, and 3 for confirmed full-off.

The public `VXBM` wrapper exposes `FAN_STATUS` at byte offset `0x5c`. Bit 0 is
`FULL_ON`, bit 1 is `VALID`, bit 2 is `FULL_OFF`, and bits `[15:8]` contain the last DAC value.
`VALID` is zero after reset and becomes one only after an acknowledged MAX6651
CONFIG control write, including an acknowledged fail-safe full-on write.
Software must not interpret `FULL_ON` or the DAC field while `VALID` is zero.

ABI 1.2 supports the public read/write `FAN_CONTROL` register at byte offset
`0x60`. Bits `[1:0]` select automatic (`0`), forced full-on (`1`), manual DAC (`2`), or forced full-off (`3`); bits `[15:8]` hold the requested DAC value. Reset selects automatic
mode with DAC `0x20`. Manual modes bypass temperature and non-fan sensor
fail-safe decisions until software writes automatic mode again. A fan-bus
write failure still prevents an unacknowledged state from becoming valid.

ABI 1.3 exposes `SENSOR_VALID` at byte offset `0x64` and the sensor engine's
packed `I2C_ERROR` register at `0x68`, so software can identify the failed
sensor transaction without treating a partial round as valid telemetry.
ABI 1.4 adds bits `[31:30]` of that register, reporting which byte of the
failed transaction was not acknowledged: `0` device address (write), `1`
register address, `2` write data, `3` device address (read, after the repeated
start). The field is only meaningful when the NACK bit is set, and it reads as
zero on ABI 1.3, so software must check the minor version before reporting it.

ABI 1.5 adds sticky per-bus drive-fault bits to `SENSOR_VALID` at byte offset
`0x64`: bits `[11:9]` for SCL and bits `[14:12]` for SDA, indexed by bus
(0 temperature, 1 fan, 2 power). A set bit means the master drove that line low
for a full phase and still read it high. They read as zero before ABI 1.5.
`CONTROL` bit 0 clears them along with the other sticky error state.

## I2C master

`board_mgmt_i2c_master` accepts one register transaction at a time. It supports
single-byte register writes and sequential reads of one to four bytes. Read
bytes are packed in bus order; a two-byte read occupies `[15:0]` and a
three-byte read occupies `[23:0]`, with the first byte most significant.

The master reports NACK, clock-stretch timeout, and stuck-bus errors. If a bus
is not idle when a command starts, it releases SDA, emits nine SCL recovery
pulses, issues STOP, and retries the command only if both lines are released.

While the master is actively pulling a line low it samples that line back. If
SCL still reads high at the end of a driven-low phase, or SDA still reads high
at the end of the START hold, the master raises `drive_fault_scl` or
`drive_fault_sda`. That separates "the bus was driven and nobody answered" from
"the drive never reached the wire", which the NACK and timeout flags alone
cannot distinguish.

## Vortex memory drain monitor

`de10pro_vortex_mem_drain` is a combinational Avalon-MM pass-through with a
target-clock-domain drain monitor. Its defaults match `vortex_mem_cdc.m0`:
33-bit address, 512-bit data, 64-bit byte-enable, and 5-bit burstcount.

An accepted read adds its word burstcount to `outstanding_read_beats`; each
`readdatavalid` beat subtracts one. While the synchronized
`drain_req_async` is asserted, any read, write, or read response resets the
quiet counter. `drain_ack` asserts only after the outstanding count is zero
and `QUIET_CYCLES` consecutive cycles contain no command or response. A
stalled command still counts as activity, and a new command immediately
revokes an asserted acknowledgement. The monitor never gates or registers
Avalon traffic.

The recommended later integration is:

1. insert `s0` after `vortex_mem_cdc.m0` and connect `m0` to
   `ddr4_ingress_pipe_ddr4a.s0`
2. clock and reset the monitor from the existing `vortex_mem_cdc.m0` domain
3. stop new Vortex memory requests, then assert `drain_req_async` and keep
   the source quiescent until the clock change completes
4. synchronize `drain_ack` at its consumer if that consumer is in another
   clock domain

`QUIET_CYCLES` must cover the maximum gap in which the clock-crossing bridge
can hold a queued command before presenting it on `m0`; the default is eight
target-clock cycles. Writes have no response channel, so a write is complete
for drain accounting when its final beat is accepted with `waitrequest=0`.

## Simulation

Run from this directory:

```sh
make test
```

The self-checking tests cover write and sequential-read data, ACK/NACK,
recoverable SDA-low, SCL-low timeout, the first fan command, device
initialization, faulted-round invalidation, atomic telemetry readback, ordered
DAC/CONFIG writes, the 55/60-degree hysteresis, persistent I2C-fault full-on
fallback, healthy-round recovery, FAN_STATUS validity, and sticky I2C bus
errors.
The drain-monitor test covers delayed queued writes, stalled writes,
outstanding burst reads, response completion, acknowledgement revocation,
transparent traffic, and recovery.
They also cover the public `VXBM` CSR layout, signed temperature and power
scales, exact-Hz profile mapping, normal clock changes, unsupported
frequencies, quiesce timeout, startup and runtime PLL lock-loss handling,
synchronized source-domain reset, registered Gray-code measurement, reset
release, and bounded timeout when drain acknowledgements repeatedly drop during
the guard interval.
