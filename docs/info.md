## How it works

This project wraps **ODIN** for Tiny Tapeout with **no off-chip SPI**. The core still uses the same internal configuration and memory paths; [`host_if.v`](../src/odin/host_if.v) replaces [`spi_slave.v`](../src/odin/spi_slave.v) (kept in the tree for reference only).

Use **`uio[7]`** to select the pin function:

| `uio[7]` | Mode | Purpose |
|----------|------|---------|
| 0 | **AER** | Real-time spike / event injection and output |
| 1 | **Host** | Parallel programming (config registers, neuron/synapse memory) |

`ui[7:0]` and `uo[7:0]` are shared: in **host** mode they carry write data / read data; in **AER** mode they carry input/output AER address bytes.

Full ODIN architecture and event types: [docs/odin/README.md](odin/README.md).

### AER mode (`uio[7]` = 0)

| Pin | Direction | Function |
|-----|-----------|----------|
| `ui[7:0]` | In | `AERIN_ADDR[7:0]` |
| `uo[7:0]` | Out | `AEROUT_ADDR[7:0]` |
| `uio[0]` | In | `AERIN_REQ` |
| `uio[1]` | Out | `AERIN_ACK` |
| `uio[2]` | Out | `AEROUT_REQ` |
| `uio[3]` | In | `AEROUT_ACK` |
| `uio[5]` | In | `AERIN_ADDR[16]` during setup |
| `uio[6]` | In | Address setup (latch `ui` as `AERIN_ADDR[15:8]`) |

Setup high address: assert `uio[6]`, drive `ui[7:0]` = `AERIN_ADDR[15:8]` and `uio[5]` = `AERIN_ADDR[16]`, then run the handshake with `uio[6]` low.

### Host mode (`uio[7]` = 1)

All strobes are synchronous to **`clk`** (not a separate SPI clock).

| Pin | Function |
|-----|----------|
| `uio[0]` | Strobe (pulse high for one `clk` cycle) |
| `uio[1]` | Write enable (1 = write, 0 = read) |
| `uio[2]` | Config access (1 = ODIN config register, 0 = neuron/synapse memory) |
| `uio[3]` | Address phase (1 = `ui` is address high byte or config reg index) |
| `uio[5:4]` | Memory `opcode` (01 = neuron mem, 10 = synapse mem; same as ODIN SPI) |
| `uio[1]` | Out (host ack / AERIN_ACK in AER mode) |
| `ui[7:0]` | Write data, or address byte |
| `uo[7:0]` | Read data (after memory read strobe) |

**Config register write:** `uio[2]=1`, strobe with `uio[3]=1` and `ui`=register index (0–25); strobe again with `uio[3]=0` and `ui`=data.

**Memory access:** `uio[2]=0`, strobe with `uio[3]=1` and `ui`=addr[15:8]; strobe with `uio[3]=0` and `ui`=addr[7:0]; strobe with `uio[3]=0`, `uio[1]` set for write/read and `ui`=data byte (writes) or capture `uo` (reads).

`SPI_GATE_ACTIVITY` defaults to 1 after reset so AER mode works without extra setup.

## How to test

```bash
cd test
make
```

Extend `test/test.py` with host-mode register writes and AER sequences.

## External hardware

Use a GPIO master on the `uio`/`ui`/`uo` pins (no SPI wiring). Keep host strobes synchronous to the chip clock from the demo board.

## Licensing

ODIN RTL: [Solderpad Hardware License v2.0](odin/ODIN_LICENSE). Documentation: CC BY 4.0 ([docs/odin/LICENSE](odin/LICENSE)).

> C. Frenkel et al., *IEEE TBioCAS*, vol. 13, no. 1, pp. 145-158, 2019.
