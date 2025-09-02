<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Tiny Tapeout JTAG Controller
## How it works
This project implements a JTAG (Joint Test Action Group) controller, adhering to the IEEE 1149.1 standard, designed for boundary scan testing and data register manipulation. The design consists of three main Verilog modules:

data_registers.v: Manages a 4-bit data register (Boundary Scan Register, BSR) that supports serial shifting, parallel input capture, and updating to a shadow register. It operates based on control signals (shift_en, capture_en, update_en) and handles serial input (TDI) and output (TDO).

jtag_tap_controller.v: Implements the JTAG Test Access Port (TAP) controller with a 16-state finite state machine (FSM) as per the IEEE 1149.1 standard. It supports instructions like EXTEST, SAMPLE, BYPASS, and IDCODE, controlling the data register operations and routing TDO output based on the current state and instruction.

tt_um_imtiaz_jtag.v: The top-level module integrates the TAP controller and data registers, interfacing with Tiny Tapeout's I/O pins. It supports two modes:

Internal Mode (ena=1): Uses an internal sequencer to drive a predefined TMS sequence and input data (TEST_MODE and PARALLEL_INPUTS).
External Mode (ena=0): Uses external inputs (ui_in[1] for TMS, ui_in[0] for TDI, ui_in[5:2] for parallel inputs) for manual JTAG control.



The TAP controller manages state transitions based on the TMS (Test Mode Select) input and clock (TCK), enabling operations like capturing parallel inputs, shifting data serially, and updating the data register. The TDO output reflects the serial output from either the instruction register, bypass register, or data register, depending on the state and instruction.
## How to test
To test the JTAG controller on the Tiny Tapeout platform, follow these steps:

Internal Mode Testing (ena=1):

Set ena to 1 to enable the internal sequencer.
Apply a clock signal to clk (mapped to TCK) and ensure rst_n is high (active-low reset).
The internal sequencer automatically drives a predefined TMS sequence (DEFAULT_TMS) to navigate the TAP FSM, shifting in the TEST_MODE (2’b00 for EXTEST) and PARALLEL_INPUTS (4’b1111).
Monitor uo_out[0] (TDO) to observe the serial output during the Shift-DR state.
Check uo_out[4:1] to verify the 4-bit data register output (tdr_data_outs), which should reflect the captured or shifted data.
Expected behavior: After the TMS sequence completes, uo_out[4:1] should match the shifted PARALLEL_INPUTS (4’b1111), and TDO will output the serial data during Shift-DR.


External Mode Testing (ena=0):

Set ena to 0 to use external inputs.
Drive clk (TCK) and ensure rst_n is high.
Provide external signals:
ui_in[0]: TDI (serial input data).
ui_in[1]: TMS (to control TAP state transitions).
ui_in[5:2]: Parallel inputs to the data register.


Manually drive TMS to navigate the TAP FSM (e.g., to Shift-IR, Shift-DR, or Update-DR states) and TDI to input serial data.
Monitor uo_out[0] (TDO) for serial output and uo_out[4:1] for the data register contents.
Example test sequence:
Drive TMS to reach Shift-IR, shift in a 2-bit instruction (e.g., 2’b00 for EXTEST).
Transition to Shift-DR, shift in 4-bit data via TDI.
Check TDO and tdr_data_outs to verify correct shifting and capture.




Reset Testing:

Assert rst_n low to reset the TAP controller to the Test-Logic-Reset state and clear all registers.
Verify uo_out[4:1] and uo_out[0] are 0 after reset.


Simulation:

Simulate the design using a Verilog simulator (e.g., Verilator or ModelSim).
Apply clock and reset signals, then test both internal and external modes by driving appropriate inputs and checking outputs against expected JTAG behavior.



## External hardware
No external hardware is required for this project, as it is designed to operate within the Tiny Tapeout ASIC framework. All inputs and outputs are mapped to the Tiny Tapeout I/O pins:

Inputs: clk (TCK), rst_n (TRST_N), ena, ui_in[0] (TDI), ui_in[1] (TMS), ui_in[5:2] (parallel inputs).
Outputs: uo_out[0] (TDO), uo_out[4:1] (data register outputs).
Bidirectional pins (uio_in, uio_out) are unused.

For testing, a signal generator or microcontroller can be used to drive the input pins (e.g., for external mode), and a logic analyzer can monitor the outputs. However, these are optional and not strictly required, as the design can be fully tested within the Tiny Tapeout environment or through simulation.
