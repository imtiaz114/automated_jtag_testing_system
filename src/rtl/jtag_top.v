`include "jtag_tap_controller.v"

module jtag_top #(
    parameter STATE_NUM      = 16,
    parameter INSTRUCTION_NUM = 4,
    parameter DATA_REG        = 5,
    parameter DATA_SIZE       = 5
) (
    input  wire tclk,
    input  wire trst_n,
    input  wire [$clog2(INSTRUCTION_NUM)-1:0] test_mode,
    input  wire [DATA_SIZE-1:0] input_data,
    output reg  [DATA_SIZE-1:0] output_data,
    input  wire [DATA_REG-1:0] parallel_inputs,
    output wire [DATA_REG-1:0] tdr_data_outs
);

  localparam int FIXED_LEN   = 18;
  localparam int TMS_SEQ_LEN = FIXED_LEN + DATA_REG + INSTRUCTION_NUM - 1;
  localparam int INSTR_START = 10;                               
  localparam int INSTR_END   = INSTR_START + INSTRUCTION_NUM;    
  localparam int DR_START    = INSTR_END + 5;                    
  localparam int DR_END      = DR_START + DATA_REG;          

  wire [DATA_REG-1:0] tdr_data_outs_reg;
  reg tms, tdi;
  wire tdo;
  reg [$clog2(TMS_SEQ_LEN)-1:0] tmsIDX;
  reg [$clog2(DATA_SIZE)-1:0]   tdiIDX, tdoIDX;
  reg [$clog2(INSTRUCTION_NUM)-1:0] instructionIDX;

  // TMS default sequence
  reg [TMS_SEQ_LEN-1:0] defaultTMS =
      { 5'b11111,                 // Test-Logic-Reset
        5'b01100,                 // go to Shift-IR path
        {INSTRUCTION_NUM{1'b0}},  // IR shift clocks
        5'b11100,                 // exit/update IR -> DR path
        {(DATA_REG-1){1'b0}},     // DR shift clocks
        3'b110                    // exit/update DR
      };

  // TAP instance
  jtag_tap_controller #(
    .STATE_NUM(STATE_NUM),
    .INSTRUCTION_NUM(INSTRUCTION_NUM),
    .DATA_REG(DATA_REG)
  ) jtag0 (
    .tclk(tclk),
    .trst_n(trst_n),
    .tdi(tdi),
    .tms(tms),
    .tdo(tdo),
    .parallel_inputs(parallel_inputs),
    .tdr_data_outs(tdr_data_outs_reg)
  );

  // Drive TMS/TDI on negedge
  always @(negedge tclk or negedge trst_n) begin
    if (!trst_n) begin
      tmsIDX         <= '0;
      tdiIDX         <= '0;
      tdoIDX         <= '0;
      instructionIDX <= '0;
      tms            <= 1'b1;
      tdi            <= 1'b0;
    end else begin
      tms <= defaultTMS[TMS_SEQ_LEN-1 - tmsIDX];
      if ((tmsIDX >= INSTR_START) && (tmsIDX < INSTR_END)) begin
        tdi <= test_mode[instructionIDX];
        instructionIDX <= instructionIDX + 1'b1;
      end else if ((tmsIDX >= DR_START) && (tmsIDX < DR_END)) begin
        tdi <= input_data[tdiIDX];
        tdiIDX <= tdiIDX + 1'b1;
      end else begin
        tdi <= 1'b0; 
      end
      if (tmsIDX != TMS_SEQ_LEN-1)
        tmsIDX <= tmsIDX + 1'b1;
    end
  end

  // Sample TDO on negedge to match JTAG shift-out timing
  always @(negedge tclk or negedge trst_n) begin
    if (!trst_n) begin
      output_data <= '0;
      tdoIDX      <= '0;
    end else begin
      if ((tmsIDX > DR_START) && (tmsIDX <= DR_END)) begin
        if (tdoIDX < DATA_SIZE) begin
          // choose order depending on how you want to compare
          output_data[DATA_SIZE-1-tdoIDX] <= tdo; // MSB-first
          // or: output_data[tdoIDX] <= tdo;      // LSB-first
          tdoIDX <= tdoIDX + 1'b1;
        end
      end
    end
  end

  assign tdr_data_outs = tdr_data_outs_reg;

endmodule
