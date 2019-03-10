
module edge_p
	(
		input logic clock,
		input logic signal,
		output logic rising,
		output logic falling
	);
	
	logic[1 : 0] shift;
	
	always_ff @ (posedge clock) begin
		shift = {shift[0], signal};
	end
	
	assign rising = shift[0] & ~shift[1];
	assign falling = shift[1] & ~shift[0];
	
endmodule



module dff_p
  (
    output reg q,
    input d,
    input clock,
    input reset
  );
  
  initial q = 1'b0;
  
  always @ (posedge clock, negedge reset) begin
    if (~reset) begin
      q <= '0;
    end else begin
      q <= d;
    end
  end

endmodule

module sync_p 
	(
		input logic clock,
		input logic reset,
		input logic d,
		output logic q
	);
	logic __q;
	
	always @ (posedge clock) begin
		if (~reset) begin
			__q <= '0;
			q 	<= '0;
		end else begin
			__q <= d;
			q 	<= __q;
		end
	end
	
endmodule

module rs_trig 
	(
		input logic set,
		input logic reset,
		output logic q,
		output logic nq
	);
	
	assign nq = ~q;
	
	always @ (negedge reset, posedge set) begin
		if (~reset) begin
			q <= '0;
		end else if (set) begin
			q <= '1;
		end
	end
	
endmodule


module pulse_p
	#(
		parameter 
			WIDTH = 4,
			ZERO_PULSES = 1'b1
	)
	(
		input logic 					clk_i,
		input logic 					trig_i,
		input logic[WIDTH - 1 : 0] count,
		input logic[WIDTH - 1 : 0] plow,
		input logic[WIDTH - 1 : 0] phi,
		input logic 					idle,
		output logic 					sig_o,
		output logic 					cyc_o
	);
	
		
	
	localparam [1 : 0]
		STATE_IDLE 		= 0,
		STATE_SETUP		= 1,
		STATE_LOW		= 2,
		STATE_HI			= 3;
	
	logic cyc;
	
	logic[1 : 0] 	state = STATE_IDLE, 
						next_state = STATE_IDLE;
	
	always_comb
		state = next_state;
	
	
	logic[WIDTH - 1 : 0] period;
	logic[WIDTH : 0] counter;
	
	
	always_ff @ (posedge clk_i) begin
		case (state)
			STATE_IDLE : begin
				sig_o <= idle;
				period <= '0;
				counter <= '0;
				if (trig_i) begin
					next_state <= STATE_SETUP;
					cyc <= '1;
				end else begin
					cyc <= '0;
				end
			end
			STATE_SETUP : begin
				counter <= (count << 1) + ZERO_PULSES;
				if (idle) begin
					period <= plow;
					next_state <= STATE_LOW;
					sig_o <= '0;
				end else begin
					sig_o <= '1;
					period <= phi;
					next_state <= STATE_HI;
				end
			end
			STATE_LOW : begin
				if (period) begin
					period <= period - 1'b1;
				end else begin
					if (counter) begin
						sig_o <= '1;
						period <= phi;
						counter <= counter - 1'b1;
						next_state <= STATE_HI;
					end else begin
						next_state <= STATE_IDLE;
					end
				end
			end
			STATE_HI : begin
				if (period) begin
					period <= period - 1'b1;
				end else begin
					if (counter) begin
						sig_o <= '0;
						period <= plow;
						counter <= counter - 1'b1;
						next_state <= STATE_LOW;
					end else begin
						next_state <= STATE_IDLE;
					end
				end
			end
		endcase
	end
	
	assign cyc_o = cyc | trig_i;
	
endmodule



module counter_4bit 
	(
		input logic clock,
		input logic[3 : 0] count,
		input logic reset,
		output logic compare,
		output logic[3 : 0] current
	);
	
	logic[3 : 0] counter;
	assign current = counter;
	assign compare = (counter >= count) ? '1 : '0;
	
	always_ff @ (posedge clock, negedge reset) begin
		if (~reset) begin
			counter = '0;
		end else if (counter < count) begin
			counter = counter + 1'b1;
		end 
	end
	
endmodule 

module counter_8bit
	(
		input logic clock,
		input logic[7 : 0] count,
		input logic reset,
		output logic compare,
		output logic[7 : 0] current
		
	);
	
	logic compare_low;
	logic compare_hi;
	
	assign compare = compare_low & compare_hi;
	
	counter_4bit counter_low
		(
			.clock(clock),
			.reset(reset),
			.count(count[3 : 0]),
			.compare(compare_low),
			.current(current[3 : 0])
		);
		
	counter_4bit counter_hi
		(
			.clock(compare_low),
			.reset(reset),
			.count(count[7 : 4]),
			.compare(compare_hi),
			.current(current[7 : 4])
		);	
	
endmodule

module counter_16bit
	(
		input logic clock,
		input logic[15 : 0] count,
		input logic reset,
		output logic compare,
		output logic[15 : 0] current
	);
	
	logic compare_low;
	logic compare_hi;
	
	assign compare = compare_low & compare_hi;
	
	counter_8bit counter_low
		(
			.clock(clock),
			.count(count[7 : 0]),
			.reset(reset),
			.compare(compare_low),
			.current(current[7 : 0])
		);
		
	counter_8bit counter_hi
		(
			.clock(compare_low),
			.count(count[15 : 8]),
			.reset(reset),
			.compare(compare_hi),
			.current(current[15 : 8])
		);
	
endmodule

module counter_p
	#(
		parameter WIDTH = 8
	)
  (
    input logic clock,
    input logic[WIDTH - 1 : 0] compare,
    input logic reset,
    output logic signal,
	output logic[WIDTH - 1 : 0] current
  );
    
  logic[WIDTH - 1 : 0] count = '0;
  
  always_comb current = count;
  
  always_comb begin
		if (count >= compare) begin
			signal = '1;
		end else begin
			signal = '0;
		end
  end
  
  always @ (posedge clock, negedge reset) begin
    if (~reset) 
      count = '0;
    else if (count < compare)
        count = count + 1'b1;
  end
  
endmodule

module mux_2to1
	(
		input logic[1 : 0] in,
		input logic select,
		output logic out
	);
	
	assign out = (select ? in[1] : in[0]);
	
endmodule

module mux_4to1
	(
		input logic[3 : 0] in,
		input logic[1 : 0] select,
		output logic out
	);
	
	always_comb begin
		case (select)
			2'd0 : out = in[0];
			2'd1 : out = in[1];
			2'd2 : out = in[2];
			2'd3 : out = in[3];
		endcase 
	end 
	
endmodule

module mux_8to1
	(
		input logic[7 : 0] in,
		input logic[2 : 0] select,
		output logic out
	);

	logic out_1, out_2;
	
	mux_4to1 mux_1
		(
			.in(in[3 : 0]),
			.select(select[1 : 0]),
			.out(out_1)
		);
		
	mux_4to1 mux_2
		(
			.in(in[7 : 4]),
			.select(select[1 : 0]),
			.out(out_2)
		);
		
	mux_2to1 mux_out
		(
			.in( {out_2, out_1} ),
			.select(select[2]),
			.out(out)
		);
		
	
endmodule

module mux_16to1
	(
		input logic[15 : 0] in,
		input logic[3 : 0] select,
		output logic out
	);
	
	logic out_1, out_2;
	
	mux_8to1 mux_1
		(
			.in(in[7 : 0]),
			.select(select[2 : 0]),
			.out(out_1)
		);
		
	mux_8to1 mux_2
		(
			.in(in[15 : 8]),
			.select(select[2 : 0]),
			.out(out_2)
		);	
		
	mux_2to1 mux_out
		(
			.in( {out_2, out_1} ),
			.select(select[3]),
			.out(out)
		);
	
endmodule

module mux_32to1
	(
		input logic[31 : 0] in,
		input logic[4 : 0] select,
		output logic out
	);
	
	logic out_1, out_2;
	
	mux_16to1 mux_1
		(
			.in(in[15 : 0]),
			.select(select[3 : 0]),
			.out(out_1)
		);
		
	mux_16to1 mux_2
		(
			.in(in[31 : 16]),
			.select(select[3 : 0]),
			.out(out_2)
		);	
		
	mux_2to1 mux_out
		(
			.in( {out_2, out_1} ),
			.select(select[4]),
			.out(out)
		);
	
endmodule


module delay
	(
		input logic clock,
		input logic enable,
		input logic in,
		output logic out
	);
	
	parameter 
		WIDTH		= 4'd9,
		INITIAL	= '1;
		
		
	logic[WIDTH - 1 : 0] __data;
	
	always @ (posedge clock) begin
		
		__data = {__data[WIDTH - 1 : 0], in};
		
		if (enable) begin
			out = __data[WIDTH - 1];
		end else begin 
			out = INITIAL;
			__data = INITIAL;
		end
	end

endmodule

module dff8
	(
		input logic clock,
		input logic reset,
		input logic[7 : 0]d, 
		output logic[7 : 0]q
	);
	
	always @ (posedge clock, negedge reset) begin
		if (~reset) begin
			q = '0;
		end else begin
			q = d;
		end
	end
	
endmodule






