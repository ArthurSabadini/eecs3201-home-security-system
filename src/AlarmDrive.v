module AlarmDrive (
	input wire clk,
	input wire [1:0] alarm_state,
	output wire buzzer,
	output reg police_led,
    output reg [2:0] alarm_leds
);
	parameter ALRMCYCLE_DELAY_1S = 50000000;   // 50*10^6 cycles => 1s (at 50MHz)
	parameter BUZZ_CYCLE_DELAY   = 65500;      // 65.5*10^3 cycles => 1.31ms (at 50MHz)

    // Alarm States
	localparam ALRMOFF = 2'b00;  // Alarm Off
	localparam ALRMON  = 2'b01;  // Alarm On
	localparam AWAYSEQ = 2'b10;  // Away Sequence
	localparam PLCCLD  = 2'b11;  // Police Called

    reg clk_1hz            = 0; 
	reg buz_clk            = 0; 
	reg buz_active         = 0; 
	reg [2:0] led_state    = 3'b010;
	reg [15:0] buz_counter = 0;
	reg [25:0] counter_1hz = 0;
	
	// Drive PMW (AC) through buzzer so it vibrates and generates sound
	BuzzerDrive(.buz_clk(buz_clk), .active(buz_active), .buzzer(buzzer));
	
	// Updating Internal clocks. State clock (1Hz) and buzzer clk (~763Hz)
	always@(posedge clk) begin
		counter_1hz <= (counter_1hz > ALRMCYCLE_DELAY_1S)? 0 : counter_1hz + 1;
		if(counter_1hz >= ALRMCYCLE_DELAY_1S) clk_1hz <= ~clk_1hz;
		
		buz_counter <= (buz_counter > BUZZ_CYCLE_DELAY)? 0 : buz_counter + 1;
		if(buz_counter >= BUZZ_CYCLE_DELAY) buz_clk <= ~buz_clk;
	end
	
	always@(posedge clk_1hz) begin 
		case(alarm_state) 
			ALRMOFF: begin
				buz_active <= 0;
				police_led <= 0;
				alarm_leds <= 0;
			end
			ALRMON: begin
			    led_state <= ~led_state;
			
				buz_active <= ~buz_active;
				police_led <= 0;
				alarm_leds <= led_state;
			end
			AWAYSEQ: begin
				buz_active <= ~buz_active;
				police_led <= 0;
				alarm_leds <= 3'b111;
			end
			PLCCLD: begin
				buz_active <= ~buz_active;
				police_led <= ~police_led;
				alarm_leds <= 0;
			end
		endcase
	end
endmodule

module BuzzerDrive (
	input wire buz_clk,
	input wire active,
	output reg buzzer
);

	always@(posedge buz_clk) begin
		if(active) 	buzzer <= ~buzzer;
		else buzzer <= 0;
	end
endmodule