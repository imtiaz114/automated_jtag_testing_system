`include "data_registers.v"

module jtag_tap_controller #(
  parameter STATE_NUM = 16,
  parameter INSTRUCTION_NUM = 4,
  parameter DATA_REG = 5
) (
  input wire tclk,
  input wire trst_n,
  input wire tdi,
  input wire tms,

  output wire tdo,

  input wire [DATA_REG-1:0] parallel_inputs,
  output wire [DATA_REG-1:0] tdr_data_outs  // FIX: changed from "output reg" to "output wire" so it can be driven by assign
);

  // defining the instructions
  localparam IR_WIDTH = $clog2(INSTRUCTION_NUM);
  parameter [IR_WIDTH-1:0] EXTEST    = 2'b00; // External Test: Boundary scan test
  parameter [IR_WIDTH-1:0] SAMPLE    = 2'b01; // Sample/Preload: Sample internal state
  parameter [IR_WIDTH-1:0] BYPASS    = 2'b10; // Bypass: 1-bit shift for quick TDO loop
  parameter [IR_WIDTH-1:0] IDCODE    = 2'b11;

  // defining the fsm states
  parameter RESET         = 4'b0000;
  parameter Run_Test_IDLE = 4'b0001;
  parameter SELECT_DR     = 4'b0010;
  parameter SELECT_IR     = 4'b0011;

  parameter CAPTURE_IR    = 4'b0100;
  parameter SHIFT_IR      = 4'b0101;
  parameter EXIT1_IR      = 4'b0110;
  parameter PAUSE_IR      = 4'b0111;

  parameter EXIT2_IR      = 4'b1000;
  parameter UPDATE_IR     = 4'b1001;
  parameter CAPTURE_DR    = 4'b1010;
  parameter SHIFT_DR      = 4'b1011;

  parameter EXIT1_DR      = 4'b1100;
  parameter PAUSE_DR      = 4'b1101;
  parameter EXIT2_DR      = 4'b1110;
  parameter UPDATE_DR     = 4'b1111;

  // defining state variables
  reg [$clog2(STATE_NUM)-1:0] state, next_state;

  // jtag registers
  reg [IR_WIDTH-1:0] reg_ir, shadow_reg_ir; // EXTEST, SAMPLE, PRELOAD, BYPASS
  wire [DATA_REG-1:0] reg_bsr;
  reg reg_bypass;

  // intermediate variables
  reg shift_en;
  reg capture_en;
  reg update_en;

  wire serial_output;
  reg tdo_reg;

  // adding data register module
  data_registers #(
    .DATA_REG(DATA_REG)
  )  bsr0 (
    .tclk(tclk),
    .trst_n(trst_n),
    .serial_input(tdi),
    .shift_en(shift_en),
    .capture_en(capture_en),
    .update_en(update_en),
    .parallel_inputs(parallel_inputs),
    .serial_output(serial_output),
    .data_regs(reg_bsr)
  );

  // state changing logic
  always @(posedge tclk or negedge trst_n) begin

    if (!trst_n) begin

      reg_bypass <= 1'b0;
      reg_ir <= SAMPLE;
      shadow_reg_ir <= SAMPLE;

      state <= RESET;
    end else begin
      state <= next_state;
    end


    // register updates
    case (state)
      CAPTURE_IR: reg_ir <= SAMPLE; // preload
      SHIFT_IR:   reg_ir <= {tdi, reg_ir[IR_WIDTH-1:1]};
      UPDATE_IR:  shadow_reg_ir <= reg_ir;

      CAPTURE_DR: if (shadow_reg_ir == BYPASS)
        reg_bypass <= 1'b0;
      SHIFT_DR:   if (shadow_reg_ir == BYPASS)
        reg_bypass <= tdi;

      default: begin
        reg_bypass <= reg_bypass;
        reg_ir <= reg_ir;
        shadow_reg_ir <= shadow_reg_ir;
      end
    endcase

  end

  // state operations and next state tasks
  always @(*) begin

    case (state)

      RESET: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? RESET : Run_Test_IDLE;
      end

      Run_Test_IDLE: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? SELECT_DR : Run_Test_IDLE;
      end

      SELECT_DR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? SELECT_IR : CAPTURE_DR;
      end

      SELECT_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? RESET : CAPTURE_IR;
      end

      CAPTURE_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? EXIT1_IR : SHIFT_IR;
      end

      SHIFT_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? EXIT1_IR : SHIFT_IR;
      end

      EXIT1_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? UPDATE_IR : PAUSE_IR;
      end

      PAUSE_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? EXIT2_IR : PAUSE_IR;
      end

      EXIT2_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? UPDATE_IR : SHIFT_IR;
      end

      UPDATE_IR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? SELECT_DR : Run_Test_IDLE;
      end

      CAPTURE_DR: begin

        shift_en   = 1'b0;
        update_en  = 1'b0;

        if (shadow_reg_ir == BYPASS) begin
          capture_en   = 1'b0;
        end else begin // extest
          capture_en   = 1'b1;
        end

        next_state = tms ? EXIT1_DR : SHIFT_DR;
      end

      SHIFT_DR: begin


        capture_en   = 1'b0;
        update_en  = 1'b0;

        if (shadow_reg_ir == BYPASS) begin
          shift_en   = 1'b0;
        end else begin // extest
          shift_en    = 1'b1;
        end

        next_state = tms ? EXIT1_DR : SHIFT_DR;
      end

      EXIT1_DR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? UPDATE_DR : PAUSE_DR;
      end

      PAUSE_DR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? EXIT2_DR : PAUSE_DR;
      end

      EXIT2_DR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = tms ? UPDATE_DR : SHIFT_DR;
      end

      UPDATE_DR: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;

        if (shadow_reg_ir == BYPASS) begin
          update_en   = 1'b0;
        end else begin // extest
          update_en   = 1'b1;
        end

        next_state = tms ? SELECT_DR : Run_Test_IDLE;
      end

      default: begin

        shift_en   = 1'b0;
        capture_en = 1'b0;
        update_en  = 1'b0;

        next_state = RESET;
      end

    endcase

  end // always

  // assigning tdo

  always @(posedge tclk or negedge trst_n) begin

    if (!trst_n)
      tdo_reg <= 1'b0;
    else begin
      if (state == SHIFT_IR)
        tdo_reg <= reg_ir[0];
      else if ((state == SHIFT_DR) && (shadow_reg_ir == BYPASS))
        tdo_reg <= reg_bypass;
      else if (state == SHIFT_DR) begin
        tdo_reg <= serial_output;
      end else
        tdo_reg <= 1'b0;
    end
  end

  // preparing the outputs
  assign tdo = tdo_reg;
  assign tdr_data_outs = reg_bsr; // OK now: tdr_data_outs is a wire

endmodule
