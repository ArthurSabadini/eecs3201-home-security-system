module SecuritySystem (
    input wire clk,                              // P11
	 
	// Inputs
    input wire multipurpose_button, mode_change, // Buttons: B8, A7
	input wire [3:0] passcode_in,                // Swicthes: C10, C11, D12, C12 (4 bits)
	 
	// Distance Sensor Communication
    input wire echo,                            // AB8
    output wire trig,                           // AB9
	 
	// Alarm Instances
    output wire buzzer, police_led,             // AB17, AA17 
    output wire [2:0] alarm_leds,               // Y10, AA11, AA12
    output wire [41:0] display 			        // Seven Segment Displays (7 leds * 6 displays = 42 leds)
);

    localparam AWAY_SEQ_DELAY_2S        = 100000000; // 100*10^6 cycles (at 50MHz) => 2s
    localparam PASSCODE_INPUT_DELAY_10S = 500000000; // 500*10^6 cyles (at 50MHz) => 10s
    localparam TRESHOLD_DISTANCE_CM     = 5;         // Threshold distance when door is opened (measured)

	// System States
	localparam UNARM =  2'b00; // Unarmed
    localparam ARMS  =  2'b01; // Alarmed Stay
    localparam ARMA  =  2'b10; // Alarmed Away
    localparam RESET =  2'b11; // Reset Passcode
	 
    // Message States
    localparam UNARM_MSG   =  3'b000; // Unarmed
    localparam ARMS_MSG    =  3'b001; // Alarmed Stay
    localparam ARMA_MSG    =  3'b010; // Alarmed Away
    localparam RESET_MSG   =  3'b011; // Reset Passcode
	localparam DISPLAY_MSG =  3'b100; // Display message (passcode)
    
    // Alarm States
    localparam ALRMOFF = 2'b00;  // Alarm Off
	localparam ALRMON  = 2'b01;  // Alarm On
	localparam AWAYSEQ = 2'b10;  // Away Sequence
	localparam PLCCLD  = 2'b11;  // Police Called
	
	// Multipurpose Button states
	localparam TURNOFF   = 2'b00;
	localparam CONFRPASS = 2'b01;
	localparam RESETPASS = 2'b10;
    
    // System Instances
    reg passcode_confirmed = 0;
    reg [2:0] mode_state   = UNARM_MSG; 
    
    // Initial Mode is Unarmed. Passcode Set to 0000
    reg [3:0] passcode     = 0;
	reg [1:0] state        = UNARM; 
	reg [1:0] alarm_state  = ALRMOFF; 
	reg [1:0] button_state = TURNOFF;

    // Initialize Counters (used for Delays)
    reg [27:0] away_seq_delay_counter = 0;
    reg [28:0] passcode_delay_counter = 0;
    
    // Distance Measured
    wire [32:0] distance_cm;
    
    ModeMessage #(
        .UNARM(UNARM_MSG), .ARMS(ARMS_MSG), .ARMA(ARMA_MSG), .RESET(RESET_MSG), .DISPLAY(DISPLAY_MSG)
    ) message(.mode(mode_state), .msg(passcode_in), .display(display));
        
	AlarmDrive (.clk(clk), .alarm_state(alarm_state), .buzzer(buzzer), .police_led(police_led), .alarm_leds(alarm_leds));
    HCSRO4 sonic(.clk(clk), .rst(1'b1), .echo(echo), .trig(trig), .distance_cm(distance_cm));
	 
	// Change System States when button pressed
	always@(negedge mode_change) state <= state + 1;
	 
	// Main logic
    always@(posedge clk or negedge mode_change or negedge multipurpose_button) begin
        if(!mode_change) begin 
            // Reset counters
			passcode_delay_counter <= 0;
			away_seq_delay_counter <= 0;
			case(state)
                UNARM: begin // Do nothing
				    button_state <= TURNOFF;
					alarm_state <= ALRMOFF;
					mode_state <= UNARM_MSG;
                end
                ARMS: begin // Trigger if door opened
					button_state <= CONFRPASS;
					alarm_state <= ALRMOFF;
					mode_state <= ARMS_MSG;
                end
                ARMA: begin // Window to leave (Signal) => Normal Mode
					button_state <= CONFRPASS;
					alarm_state <= AWAYSEQ;
					mode_state <= ARMA_MSG;
					away_seq_delay_counter <= 1; // Starting counting
                end
                RESET: begin
					button_state <= CONFRPASS;
					alarm_state <= ALRMOFF;
					mode_state <= RESET_MSG;
                end
                default: begin // Perform UNARM for some unvalid state
                    button_state <= TURNOFF;
					alarm_state <= ALRMOFF;
					mode_state <= UNARM_MSG;
                end
            endcase
        end else if (!multipurpose_button) begin // On Multipurpose Button press
			case(button_state)
				TURNOFF: begin 
				    alarm_state <= ALRMOFF;
				end
				CONFRPASS: begin // If passcode confirmed, continue to reset/turn off alarm
					passcode_confirmed <= 0;
					if(passcode == passcode_in) begin 
						passcode_confirmed <= 1;
						case(state)
							RESET: begin 
							    // If passcode confirmed on RESET mode => Reset passcode
								button_state <= RESETPASS;
							end
						    ARMS: begin 
						        // If passcode confirmed on Alarmed Stay => Turn off alarm and reset counters
								alarm_state <= ALRMOFF;
								passcode_delay_counter <= 0;
							    away_seq_delay_counter <= 0;
							end
							ARMA: begin 
							    // If passcode confirmed on Alarmed Away => Turn off alarm and reset counters
							    alarm_state <= ALRMOFF;
								passcode_delay_counter <= 0;
								away_seq_delay_counter <= 0;
							end
					    endcase
					end
				end
				RESETPASS: begin
				    // Follow to reset passcode
				    button_state <= CONFRPASS;
					mode_state <= DISPLAY_MSG; // Display new passcode
					passcode <= passcode_in;
					passcode_confirmed <= 0;
				end
				default: button_state <= CONFRPASS; // On unvalid state => confirm passcode
			endcase
        end else begin
            case(state)
                ARMS: begin // Trigger if door opened 
                    if(alarm_state == ALRMON) begin
                        // Wait 10 secs
                        if(passcode_delay_counter  < PASSCODE_INPUT_DELAY_10S) begin 
                            passcode_delay_counter <= passcode_delay_counter + 1;
                        end else passcode_delay_counter <= 0;
                            
                        // Within 10 secs, confirm passcode
                        if(passcode_delay_counter > 0) begin
                            if(passcode_confirmed) begin // Turn off alarm
							    alarm_state <= ALRMOFF;
							    passcode_delay_counter <= 0;
							end
                        end else if (!passcode_delay_counter) begin // Else, police called
                            alarm_state <= PLCCLD;
                        end
                    end else if(distance_cm < TRESHOLD_DISTANCE_CM) begin // Check if door has been opened
                        alarm_state <= ALRMON; // Door opened => Alarm Activated
                    end	  
                end
                ARMA: begin // Window to leave (Signal) => Normal Mode
                    if(away_seq_delay_counter > 0) begin
                        // Play Away Sequence for 2 secs
                        if(away_seq_delay_counter  < AWAY_SEQ_DELAY_2S) begin 
                            away_seq_delay_counter <= away_seq_delay_counter + 1;
                        end else begin 
							away_seq_delay_counter <= 0;
							alarm_state <= ALRMOFF;
						end
                    end else begin // Same code as in ARMS
                        if(alarm_state == ALRMON) begin
                            // Wait 10 secs
						    if(passcode_delay_counter  < PASSCODE_INPUT_DELAY_10S) begin 
						        passcode_delay_counter <= passcode_delay_counter + 1;
							end else passcode_delay_counter <= 0;
										 
							// Within 10 secs, confirm passcode
							if(passcode_delay_counter > 0) begin
								if(passcode_confirmed) begin // Turn off alarm
								    alarm_state <= ALRMOFF;
									passcode_delay_counter <= 0;
								end
							end else if (!passcode_delay_counter) begin // Else, police called
								alarm_state <= PLCCLD;
							end
						end else if(distance_cm < TRESHOLD_DISTANCE_CM) begin // Check if door has been opened
							alarm_state <= ALRMON; // Door opened => Alarm Activated
						end
                    end
                end
            endcase 
        end
    end
endmodule