// ODIN behavioral SRAM → sky130 1 KiB OpenRAM macros.

module SRAM_256x128_wrapper (
    input          RSTN,
    input          CK,
    input          CS,
    input          WE,
    inout          VPWR,
    inout          VGND,
    input  [  7:0] A,
    input  [127:0] D,
    output [127:0] Q
);
    wire active = CS;
    wire [7:0] lane_dout [0:15];
    wire [7:0] lane_dout_unused [0:15];
    wire [127:0] macro_dout;
    wire _rstn_unused = RSTN;

    genvar lane;
    generate
        for (lane = 0; lane < 16; lane = lane + 1) begin : neur_lanes
            sky130_sram_1kbyte_1rw1r_8x1024_8 neur_lane (
                .vccd1 (VPWR),
                .vssd1 (VGND),
                .clk0  (CK),
                .csb0  (~active),
                .web0  (~(active & WE)),
                .wmask0(1'b1),
                .addr0 ({2'b00, A}),
                .din0  (D[lane*8 +: 8]),
                .dout0 (lane_dout[lane]),
                .clk1  (CK),
                .csb1  (1'b1),
                .addr1 (10'b0),
                .dout1 (lane_dout_unused[lane])
            );
            assign macro_dout[lane*8 +: 8] = lane_dout[lane];
        end
    endgenerate

    reg [127:0] Qr;
    always @(posedge CK) begin
        if (CS)
            Qr <= macro_dout;
    end
    assign Q = Qr;
endmodule


module SRAM_8192x32_wrapper (
    input         RSTN,
    input         CK,
    input         CS,
    input         WE,
    inout         VPWR,
    inout         VGND,
    input  [12:0] A,
    input  [31:0] D,
    output [31:0] Q
);
    wire _rstn_unused = RSTN;

    wire [7:0] macro_byte_dout [0:31];
    wire [7:0] macro_byte_dout_unused [0:31];
    wire [31:0] depth_dout [0:7];
    wire        depth_sel [0:7];

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : syn_banks
            localparam integer DEPTH_BANK = g % 8;
            localparam integer BYTE_LANE = g / 8;
            sky130_sram_1kbyte_1rw1r_8x1024_8 syn_sram (
                .vccd1 (VPWR),
                .vssd1 (VGND),
                .clk0  (CK),
                .csb0  (~depth_sel[DEPTH_BANK]),
                .web0  (~(depth_sel[DEPTH_BANK] & WE)),
                .wmask0(1'b1),
                .addr0 (A[9:0]),
                .din0  (D[BYTE_LANE*8 +: 8]),
                .dout0 (macro_byte_dout[g]),
                .clk1  (CK),
                .csb1  (1'b1),
                .addr1 (10'b0),
                .dout1 (macro_byte_dout_unused[g])
            );
        end

        for (g = 0; g < 8; g = g + 1) begin : syn_depth_banks
            assign depth_sel[g] = CS && (A[12:10] == g);
            assign depth_dout[g] = {
                macro_byte_dout[24 + g],
                macro_byte_dout[16 + g],
                macro_byte_dout[8 + g],
                macro_byte_dout[g]
            };
        end
    endgenerate

    reg [31:0] macro_dout;
    integer i;
    always @* begin
        macro_dout = 32'b0;
        for (i = 0; i < 8; i = i + 1)
            if (depth_sel[i])
                macro_dout = depth_dout[i];
    end

    reg [31:0] Qr;
    always @(posedge CK) begin
        if (CS)
            Qr <= macro_dout;
    end
    assign Q = Qr;
endmodule
