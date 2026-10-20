// Copyright (C) 2016-2019 Université catholique de Louvain (UCLouvain), Belgium.
// SPDX-License-Identifier: SHL-2.0
//
// ODIN on Tiny Tapeout — no off-chip SPI. Configuration and memory access use a
// parallel host port on uio (mode=1); spike events use ui/uo + uio (mode=0).

`default_nettype none

module tt_um_wajahat_odin (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n,
    inout  wire       VPWR,
    inout  wire       VGND
);

  wire mode_host = uio_in[7];

  // --- AER mode (uio[7]=0) ---
  wire        aer_setup   = uio_in[6];
  wire        aerin_req   = uio_in[0];
  wire        aerout_ack  = uio_in[3];
  wire        aer_addr16  = uio_in[5];

  reg  [ 7:0] aer_addr_hi;
  reg         aer_addr_msb;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aer_addr_hi  <= 8'h00;
      aer_addr_msb <= 1'b0;
    end else if (!mode_host && aer_setup) begin
      aer_addr_hi  <= ui_in;
      aer_addr_msb <= aer_addr16;
    end
  end

  wire [16:0] aerin_addr = {aer_addr_msb, aer_addr_hi, ui_in};

  wire        aerin_ack;
  wire        aerout_req;
  wire [ 7:0] aerout_addr;

  // --- Host mode (uio[7]=1): parallel access to ODIN config / memories ---
  wire        host_stb      = mode_host & uio_in[0];
  wire        host_we       = uio_in[1];
  wire        host_conf     = uio_in[2];
  wire        host_addr_hi  = uio_in[3];
  wire [ 1:0] host_opcode   = uio_in[5:4];
  wire [ 7:0] host_wdata    = ui_in;
  wire [ 7:0] host_rdata;
  wire        host_ack;

  ODIN odin_core (
      .CLK          (clk),
      .RST          (~rst_n),
      .VPWR         (VPWR),
      .VGND         (VGND),
      .HOST_STB     (host_stb),
      .HOST_WE      (host_we),
      .HOST_CONF    (host_conf),
      .HOST_ADDR_HI (host_addr_hi),
      .HOST_OPCODE  (host_opcode),
      .HOST_WDATA   (host_wdata),
      .HOST_RDATA   (host_rdata),
      .HOST_ACK     (host_ack),
      .AERIN_ADDR   (aerin_addr),
      .AERIN_REQ    (mode_host ? 1'b0 : aerin_req),
      .AERIN_ACK    (aerin_ack),
      .AEROUT_ADDR  (aerout_addr),
      .AEROUT_REQ   (aerout_req),
      .AEROUT_ACK   (mode_host ? 1'b0 : aerout_ack)
  );

  wire [7:0] uo_aer = aerout_addr;
  wire [7:0] uo_host = host_rdata;

  assign uo_out = mode_host ? uo_host : uo_aer;

  assign uio_oe = mode_host ? 8'b0000_0010 : 8'b0000_0110;

  assign uio_out[0] = 1'b0;
  assign uio_out[1] = mode_host ? host_ack : aerin_ack;
  assign uio_out[2] = mode_host ? 1'b0 : aerout_req;
  assign uio_out[3] = 1'b0;
  assign uio_out[4] = 1'b0;
  assign uio_out[5] = 1'b0;
  assign uio_out[6] = 1'b0;
  assign uio_out[7] = 1'b0;

  wire _unused = &{ena, 1'b0};

endmodule
