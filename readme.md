# JTAG Interface Implementation
This repository contains a Verilog implementation of a JTAG (Joint Test Action Group) interface, designed to comply with the IEEE 1149.1 standard. The design includes a top-level module, a TAP (Test Access Port) controller, and data registers, providing a robust framework for boundary scan testing, internal state sampling, and bypass functionality. The codebase is structured for modularity, scalability, and ease of integration into larger digital systems.
Repository Structure

data_registers.v: Implements the data register module for serial and parallel data handling.
jtag_tap_controller.v: Defines the TAP controller FSM (Finite State Machine) and instruction/data register logic.
jtag_top.v: Integrates the TAP controller and manages JTAG operations with configurable parameters.

# Design Overview
The JTAG interface is parameterized to support customizable data register sizes, instruction widths, and state machine configurations. It supports standard JTAG instructions such as EXTEST, SAMPLE, BYPASS, and IDCODE. The design operates on a single test clock (tclk) and includes active-low reset (trst_n) for robust initialization.
Key Features

## Parameterized Design: 
Configurable data register width (DATA_REG), instruction width (INSTRUCTION_NUM), and state machine states (STATE_NUM).
## Standard JTAG Instructions:
EXTEST: For boundary scan testing.
SAMPLE: For sampling internal states.
BYPASS: For bypassing the device with a 1-bit shift register.
IDCODE: For device identification.


# Modular Architecture: 
Separates data registers, TAP controller, and top-level control for easy modification and reuse.
Edge-Triggered Operations: Uses posedge and negedge of tclk for stable shifting and updating.
Reset Handling: Active-low reset (trst_n) ensures predictable initialization.

## Module Descriptions
## 1. data_registers.v
This module manages the JTAG data registers, supporting serial shifting, parallel capture, and update operations.
Parameters

##DATA_REG: 
Width of the data registers (default: 64).

Ports

### Inputs:
tclk: Test clock.
trst_n: Active-low test reset.
serial_input: Serial data input (TDI).
shift_en: Enable signal for shifting data.
capture_en: Enable signal for capturing parallel inputs.
update_en: Enable signal for updating shadow registers.
parallel_inputs: Parallel input data (DATA_REG bits).


### Outputs:
serial_output: Serial data output (TDO).
data_regs: Data register output (DATA_REG bits).



### Functionality

Reset: Clears data_regs to zero on trst_n low.
Capture: Loads parallel_inputs into data_regs when capture_en is high.
Shift: Shifts serial_input into data_regs when shift_en is high.
Update: Transfers data_regs to shadow_data_regs on update_en high, using negedge tclk for stability.

## 2. jtag_tap_controller.v
This module implements the JTAG TAP controller FSM and manages instruction and data registers.
### Parameters

STATE_NUM: Number of FSM states (default: 16).
INSTRUCTION_NUM: Number of supported instructions (default: 4).
DATA_REG: Width of data registers (default: 5).

### Ports

#### Inputs:
tclk: Test clock.
trst_n: Active-low test reset.
tdi: Test data input.
tms: Test mode select.
parallel_inputs: Parallel input data (DATA_REG bits).


#### Outputs:
tdo: Test data output.
tdr_data_outs: Data register outputs (DATA_REG bits).



### Functionality

Implements the 16-state JTAG FSM per IEEE 1149.1 (e.g., RESET, Run_Test_IDLE, SHIFT_DR, UPDATE_IR).
Supports instruction register (reg_ir) and bypass register (reg_bypass).
Controls data register operations via shift_en, capture_en, and update_en.
Outputs tdo based on the current state and instruction.

## 3. jtag_top.v
This top-level module integrates the TAP controller and provides an interface for external control.
## Parameters

STATE_NUM: Number of FSM states (default: 16).
INSTRUCTION_NUM: Number of instructions (default: 4).
DATA_REG: Data register width (default: 5).
DATA_SIZE: Input/output data width (default: 5).

## Ports

### Inputs:
tclk: Test clock.
trst_n: Active-low test reset.
test_mode: Instruction selection ($clog2(INSTRUCTION_NUM) bits).
input_data: Input data for shifting (DATA_SIZE bits).
parallel_inputs: Parallel input data (DATA_REG bits).


### Outputs:
output_data: Output data from TDO (DATA_SIZE bits).
tdr_data_outs: Data register outputs (DATA_REG bits).



## Functionality

Drives TMS and TDI signals based on a predefined sequence (defaultTMS).
Samples TDO to capture output data.
Supports parameterized instruction and data shifting.

# Testbench Guidelines
To verify the functionality of this JTAG implementation, a comprehensive testbench should be developed following standard RTL verification practices. Below are the recommended guidelines:
## Testbench Objectives
1. Verify FSM state transitions per IEEE 1149.1.
2. Test all supported instructions (EXTEST, SAMPLE, BYPASS, IDCODE).
3. Validate serial and parallel data operations.
4. Ensure proper reset behavior.
5. Check timing for posedge/negedge operations.

## Testbench Structure

### Clock and Reset Generation:
Generate tclk with a fixed period (e.g., 10 ns).
Apply trst_n low for reset, then high for normal operation.


### Stimulus Generation:
Drive tms to navigate the FSM states (e.g., RESET → Run_Test_IDLE → SHIFT_IR).
Provide test_mode to select instructions.
Inject input_data and parallel_inputs for data register testing.


### Response Checking:
Monitor tdo for correct serial output.
Verify tdr_data_outs and output_data against expected values.
Check data_regs for correct capture and shift operations.


### Corner Cases:
Test reset during active operations.
Verify behavior with maximum/minimum DATA_REG and INSTRUCTION_NUM.
Simulate rapid TMS transitions to stress the FSM.


### Coverage Metrics:
Achieve 100% functional coverage for FSM states and instructions.
Ensure toggle coverage for all registers and signals.
Verify boundary conditions for data widths.



## Example Testbench Outline
module tb_jtag_top;
  // Parameters
  parameter DATA_REG = 5;
  parameter DATA_SIZE = 5;
  parameter INSTRUCTION_NUM = 4;
  parameter STATE_NUM = 16;

  // Signals
  reg tclk, trst_n;
  reg [$clog2(INSTRUCTION_NUM)-1:0] test_mode;
  reg [DATA_SIZE-1:0] input_data;
  reg [DATA_REG-1:0] parallel_inputs;
  wire [DATA_SIZE-1:0] output_data;
  wire [DATA_REG-1:0] tdr_data_outs;

  // Clock generation
  initial begin
    tclk = 0;
    forever #5 tclk = ~tclk;
  end

  // DUT instantiation
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

  // Test stimulus
  initial begin
