`default_nettype none
`timescale 1ns / 1ps

module tb ();

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  wire [6:0] neur_event_out;
  wire       aerout_req_core;
  wire [7:0] aerout_addr_core;

  assign neur_event_out    = user_project.odin_core.NEUR_EVENT_OUT;
  assign aerout_req_core   = user_project.odin_core.AEROUT_REQ;
  assign aerout_addr_core  = user_project.odin_core.AEROUT_ADDR;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_wajahat_odin user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
