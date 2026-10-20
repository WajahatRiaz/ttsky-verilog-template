// Parallel host port for ODIN (Tiny Tapeout). Replaces off-chip SPI with a
// synchronous interface that drives the same controller signals as spi_slave.

module host_if #(
    parameter N = 256,
    parameter M = 8
)(
    input  wire                 CLK,
    input  wire                 RST_async,

    input  wire                 host_stb,
    input  wire                 host_we,
    input  wire                 host_conf,
    input  wire                 host_addr_hi,
    input  wire [          1:0] host_opcode,
    input  wire [         7:0] host_wdata,

    output reg                  host_ack,
    output reg  [         7:0] host_rdata,

    output reg                  CTRL_READBACK_EVENT,
    output reg                  CTRL_PROG_EVENT,
    output reg  [      2*M-1:0] CTRL_SPI_ADDR,
    output reg  [          1:0] CTRL_OP_CODE,
    output reg  [      2*M-1:0] CTRL_PROG_DATA,
    input  wire [         31:0] SYNARRAY_RDATA,
    input  wire [        127:0] NEUR_STATE,

    output reg                  SPI_GATE_ACTIVITY,
    output reg                  SPI_OPEN_LOOP,
    output reg  [        N-1:0] SPI_SYN_SIGN,
    output reg  [         19:0] SPI_BURST_TIMEREF,
    output reg                  SPI_OUT_AER_MONITOR_EN,
    output reg                  SPI_AER_SRC_CTRL_nNEUR,
    output reg  [        M-1:0] SPI_MONITOR_NEUR_ADDR,
    output reg  [        M-1:0] SPI_MONITOR_SYN_ADDR,
    output reg                  SPI_UPDATE_UNMAPPED_SYN,
    output reg                  SPI_PROPAGATE_UNMAPPED_SYN,
    output reg                  SPI_SDSP_ON_SYN_STIM
);

    wire [31:0] readback_weight;
    wire [127:0] readback_neuron;

    assign readback_weight = SYNARRAY_RDATA >> (({3'b0, CTRL_SPI_ADDR[2*M-2:2*M-3]} << 3));
    assign readback_neuron = NEUR_STATE >> (({3'b0, CTRL_SPI_ADDR[2*M-1:M]} << 3));

    reg [7:0] addr_hi;
    reg [7:0] conf_reg;
    reg [2:0] timeref_cnt;

    genvar i;

    always @(posedge CLK or posedge RST_async) begin
        if (RST_async) begin
            host_ack              <= 1'b0;
            host_rdata            <= 8'h00;
            CTRL_READBACK_EVENT   <= 1'b0;
            CTRL_PROG_EVENT       <= 1'b0;
            CTRL_SPI_ADDR         <= {(2*M){1'b0}};
            CTRL_OP_CODE          <= 2'b0;
            CTRL_PROG_DATA        <= {(2*M){1'b0}};
            addr_hi               <= 8'h00;
            conf_reg              <= 8'h00;
            timeref_cnt           <= 3'd0;
            SPI_GATE_ACTIVITY     <= 1'b1;
            SPI_OPEN_LOOP         <= 1'b0;
            SPI_BURST_TIMEREF     <= 20'h0;
            SPI_OUT_AER_MONITOR_EN <= 1'b0;
            SPI_AER_SRC_CTRL_nNEUR <= 1'b0;
            SPI_MONITOR_NEUR_ADDR <= {M{1'b0}};
            SPI_MONITOR_SYN_ADDR  <= {M{1'b0}};
            SPI_UPDATE_UNMAPPED_SYN <= 1'b0;
            SPI_PROPAGATE_UNMAPPED_SYN <= 1'b0;
            SPI_SDSP_ON_SYN_STIM  <= 1'b0;
        end else begin
            host_ack            <= 1'b0;
            CTRL_READBACK_EVENT <= 1'b0;
            CTRL_PROG_EVENT     <= 1'b0;

            if (!host_stb)
                ;

            else if (host_conf) begin
                host_ack <= 1'b1;
                if (host_addr_hi)
                    conf_reg <= host_wdata;
                else begin
                    case (conf_reg)
                        8'd0:  SPI_GATE_ACTIVITY     <= host_wdata[0];
                        8'd1:  SPI_OPEN_LOOP         <= host_wdata[0];
                        8'd18: begin
                            if (timeref_cnt == 3'd0)
                                SPI_BURST_TIMEREF[19:12] <= host_wdata;
                            else if (timeref_cnt == 3'd1)
                                SPI_BURST_TIMEREF[11:4] <= host_wdata;
                            else
                                SPI_BURST_TIMEREF[3:0] <= host_wdata[3:0];
                            timeref_cnt <= timeref_cnt + 3'd1;
                        end
                        8'd19: SPI_AER_SRC_CTRL_nNEUR <= host_wdata[0];
                        8'd20: SPI_OUT_AER_MONITOR_EN <= host_wdata[0];
                        8'd21: SPI_MONITOR_NEUR_ADDR <= host_wdata[M-1:0];
                        8'd22: SPI_MONITOR_SYN_ADDR  <= host_wdata[M-1:0];
                        8'd23: SPI_UPDATE_UNMAPPED_SYN <= host_wdata[0];
                        8'd24: SPI_PROPAGATE_UNMAPPED_SYN <= host_wdata[0];
                        8'd25: SPI_SDSP_ON_SYN_STIM <= host_wdata[0];
                        default: ;
                    endcase
                end
            end else begin
                host_ack <= 1'b1;
                if (host_addr_hi)
                    addr_hi <= host_wdata;
                else begin
                    CTRL_SPI_ADDR <= {addr_hi, host_wdata};
                    CTRL_OP_CODE  <= host_opcode;
                    if (host_we) begin
                        CTRL_PROG_EVENT <= (host_opcode != 2'b00);
                        CTRL_PROG_DATA  <= {addr_hi, host_wdata};
                    end else if (host_opcode != 2'b00) begin
                        CTRL_READBACK_EVENT <= 1'b1;
                        if (host_opcode == 2'b10)
                            host_rdata <= readback_weight[7:0];
                        else if (host_opcode == 2'b01)
                            host_rdata <= readback_neuron[7:0];
                    end
                end
            end
        end
    end

    generate
        for (i = 0; i < (N >> 4); i = i + 1) begin : gen_syn_sign
            always @(posedge CLK or posedge RST_async) begin
                if (RST_async)
                    SPI_SYN_SIGN[16*i+15:16*i] <= 16'h0;
                else if (host_stb && host_conf && !host_addr_hi && conf_reg == (8'd2 + i[7:0]))
                    SPI_SYN_SIGN[16*i+15:16*i] <= {8'b0, host_wdata};
            end
        end
    endgenerate

    /* verilator lint_off UNUSEDSIGNAL */
    wire _lint_sink;
    assign _lint_sink = |{readback_weight[31:8], readback_neuron[127:8]};
    /* verilator lint_on UNUSEDSIGNAL */

endmodule
