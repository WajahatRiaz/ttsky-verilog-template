# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout, SimTimeoutError


# uio pin helpers (AER mode: uio[7]=0)
UIO_AERIN_REQ = 1 << 0
UIO_AEROUT_ACK = 1 << 3
UIO_AER_SETUP = 1 << 6

# Host mode: uio[7]=1
UIO_MODE_HOST = 1 << 7
UIO_HOST_STB = 1 << 0
UIO_HOST_WE = 1 << 1
UIO_HOST_CONF = 1 << 2
UIO_HOST_ADDR_HI = 1 << 3


def pack_uio(base: int, **bits) -> int:
    v = base
    for idx, val in bits.items():
        if val:
            v |= 1 << idx
    return v


async def reset_dut(dut, cycles=20):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, cycles)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


async def host_strobe(dut, uio_base: int, ui_byte: int):
    """One host transaction strobe (uio[7]=1)."""
    dut.ui_in.value = ui_byte
    dut.uio_in.value = uio_base | UIO_MODE_HOST | UIO_HOST_STB
    await RisingEdge(dut.clk)
    dut.uio_in.value = uio_base | UIO_MODE_HOST
    await RisingEdge(dut.clk)


async def host_conf_write(dut, reg_id: int, data: int):
    await host_strobe(
        dut,
        UIO_HOST_CONF | UIO_HOST_ADDR_HI,
        reg_id & 0xFF,
    )
    await host_strobe(dut, UIO_HOST_CONF | UIO_HOST_WE, data & 0xFF)


async def aer_load_addr_high(dut, addr_msb: int, addr_15_8: int):
    dut.ui_in.value = addr_15_8 & 0xFF
    dut.uio_in.value = UIO_AER_SETUP | ((addr_msb & 1) << 5)
    await ClockCycles(dut.clk, 2)
    dut.uio_in.value = 0


async def aer_in_event(dut, addr_low: int, timeout_ns=50_000):
    """Four-phase AER input handshake with latched high address."""
    dut.ui_in.value = addr_low & 0xFF
    dut.uio_in.value = UIO_AERIN_REQ

    async def wait_ack_high():
        while True:
            await RisingEdge(dut.clk)
            if int(dut.uio_out.value) & (1 << 1):
                return

    async def wait_ack_low():
        while True:
            await RisingEdge(dut.clk)
            if not (int(dut.uio_out.value) & (1 << 1)):
                return

    try:
        await with_timeout(wait_ack_high(), timeout_ns, "ns")
        dut.uio_in.value = 0
        await with_timeout(wait_ack_low(), timeout_ns, "ns")
        return True
    except SimTimeoutError:
        dut.uio_in.value = 0
        dut._log.warning("AERIN handshake timed out (no AERIN_ACK)")
        return False


async def monitor_neuron_activity(dut):
    """Print internal spike flags and output AER spikes."""
    prev_internal_spike = 0
    prev_aerout = 0
    while True:
        await RisingEdge(dut.clk)
        ev = dut.neur_event_out.value
        if ev.is_resolvable:
            internal = int(ev)
            spike = (internal >> 6) & 1
            if spike and not prev_internal_spike:
                msg = f"NEURON activity (core): event=0x{internal & 0x7F:02x}"
                print(msg, flush=True)
                dut._log.info(msg)
            prev_internal_spike = spike

        req = dut.aerout_req_core.value
        if req.is_resolvable:
            aerout = int(req)
            if aerout and not prev_aerout:
                addr = dut.aerout_addr_core.value
                if addr.is_resolvable:
                    msg = f"AEROUT spike: neuron id {int(addr)}"
                    print(msg, flush=True)
                    dut._log.info(msg)
            prev_aerout = aerout if req.is_resolvable else prev_aerout


@cocotb.test()
async def test_odin_neuron_activity(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    cocotb.start_soon(monitor_neuron_activity(dut))

    spike_count = {"n": 0}

    async def count_spikes():
        prev = 0
        while True:
            await RisingEdge(dut.clk)
            req = dut.aerout_req_core.value
            if req.is_resolvable and int(req) and not prev:
                spike_count["n"] += 1
            prev = int(req) if req.is_resolvable else 0

    cocotb.start_soon(count_spikes())

    await reset_dut(dut)

    # ODIN only accepts AER when SPI_GATE_ACTIVITY=0 (see controller WAIT state).
    dut._log.info("Host: clearing SPI_GATE_ACTIVITY so AER input is enabled")
    await host_conf_write(dut, 0, 0)
    await ClockCycles(dut.clk, 10)

    # Virtual event: neuron 0, excitatory weight 7, pattern {w,s,l,001} -> 0xE1
    await aer_load_addr_high(dut, addr_msb=0, addr_15_8=0)
    dut._log.info("Sending virtual AER event to neuron 0 (addr low 0xE1)")
    assert await aer_in_event(dut, 0xE1), "AERIN handshake failed (expected AERIN_ACK)"

    dut._log.info("Virtual AER event accepted — waiting for scheduler / neuron updates")
    await ClockCycles(dut.clk, 20000)

    print(
        f"Simulation done: {spike_count['n']} AEROUT spike(s) observed "
        "(program neurons via host mode for richer activity)",
        flush=True,
    )
    dut._log.info("Simulation finished — see stdout for NEURON / AEROUT lines")
