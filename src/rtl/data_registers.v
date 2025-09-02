module data_registers #(
	parameter DATA_REG = 64
) (
  	input wire tclk,
  	input wire trst_n,
	input wire serial_input, // 1 bit input -> tdi
  	input wire shift_en,
  	input wire capture_en,
  	input wire update_en,
    input wire [DATA_REG-1:0] parallel_inputs, // same size as data registers
  
  	output wire serial_output, // 1 bit output -> tdo
    output reg [DATA_REG-1:0] data_regs  // same size as data registers
);
  
  // setting up intermediate registers
  reg [DATA_REG-1:0] shadow_data_regs;
  

  // shifting
  always @(posedge tclk or negedge trst_n) begin

      if (!trst_n) begin // reset condition
        data_regs <= {DATA_REG{1'b0}};
      end else if (capture_en) begin
        data_regs <= parallel_inputs;
      end else if (shift_en) begin
        data_regs <= {serial_input, data_regs[DATA_REG-1:1]}; // new data comes to highest index of the register 
        
      end   
  end

  // updating
  always @(negedge tclk or negedge trst_n) begin // use negedge for stability
    if (!trst_n) begin
      shadow_data_regs <= {DATA_REG{1'b0}};
    end else if (update_en) begin
      shadow_data_regs <= data_regs; // Latch to shadow register
    end
    
  end
  
  // assigning serial output
  assign serial_output = data_regs[0];
  
endmodule