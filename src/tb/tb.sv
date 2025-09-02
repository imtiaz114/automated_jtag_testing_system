`timescale 1ns/1ps

module tb_jtag;

  // Parameters
  localparam STATE_NUM       = 16;
  localparam INSTRUCTION_NUM = 4;
  localparam DATA_REG        = 5;
  localparam DATA_SIZE       = 5;

  // DUT inputs/outputs
  reg tclk;
  reg trst_n;
  reg [$clog2(INSTRUCTION_NUM)-1:0] test_mode;
  reg  [DATA_SIZE-1:0] input_data;
  wire [DATA_SIZE-1:0] output_data;
  reg  [DATA_REG-1:0]  parallel_inputs;
  wire [DATA_REG-1:0]  tdr_data_outs;

  // Instantiate DUT
  jtag_top #(
    .STATE_NUM(STATE_NUM),
    .INSTRUCTION_NUM(INSTRUCTION_NUM),
    .DATA_REG(DATA_REG),
    .DATA_SIZE(DATA_SIZE)
  ) dut (
    .tclk(tclk),
    .trst_n(trst_n),
    .test_mode(test_mode),
    .input_data(input_data),
    .output_data(output_data),
    .parallel_inputs(parallel_inputs),
    .tdr_data_outs(tdr_data_outs)
  );

  // Clock generation
  initial begin
    tclk = 0;
    forever #5 tclk = ~tclk; // 100MHz clock
  end
  
  function automatic [DATA_SIZE-1:0] reverse_bits(input [DATA_SIZE-1:0] val);
  integer i;
  begin
    for (i = 0; i < DATA_SIZE; i++) begin
      reverse_bits[i] = val[DATA_SIZE-1-i];
    end
  end
endfunction

  // Scoreboard
  task automatic check_result(
      input [DATA_SIZE-1:0] exp_output,
      input [DATA_REG-1:0]  exp_tdr);
    begin
      @(posedge tclk); // sample after a clock

      if (output_data !== exp_output) begin
        $error("Mismatch output_data: Expected=0x%b, Got=0x%b", exp_output, output_data);
      end else begin
        $display("[%0t] [PASS] Output matches expected: 0x%b", $time, output_data);
      end

      if (tdr_data_outs !== exp_tdr) begin
        $error("Mismatch tdr_data_outs: Expected=0x%b, Got=0x%b", exp_tdr, tdr_data_outs);
      end else begin
        $display("[%0t] [PASS] TDR matches expected: 0x%b", $time, tdr_data_outs);
      end
    end
  endtask

  // Stimulus
  initial begin
    // Dump waves
    $dumpfile("jtag_tb.vcd");
    $dumpvars(0, tb_jtag);

    // Initialize inputs
    trst_n          = 0;
    test_mode       = '0;
    input_data      = '0;
    parallel_inputs = '0;

    // Hold reset for a few cycles
    repeat (4) @(posedge tclk);
    trst_n = 1;

    // Apply test instruction (EXTEST = 2'b00 for example)
    test_mode = 2'b00;

    // Apply parallel inputs for capture
    parallel_inputs = 5'b10111; // 4'b1110; // 5'b10101; // 

    // Shift this serial input data
    input_data = 5'b11001; // 4'b1101;

    // Wait enough cycles for full TMS sequence to complete
    repeat (60) @(posedge tclk);

    // Scoreboard check (fixed expectations):
    // - Output data = shifted out captured parallel_inputs (collected MSB-first now)
    // - TDR contents = shifted in new input_data
    check_result(reverse_bits(parallel_inputs), input_data);

    $display("Simulation completed");
    $finish;
  end

endmodule
