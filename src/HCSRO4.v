module HCSRO4 (
    input wire clk,               // 50MHz System clock
    input wire rst,               // reset button
    input wire echo,              // Response from sensor
    output reg trig,              // Pulse input to make a measurement
    output reg [32:0] distance_cm // Distance output in cm
);

    // Delay params
    parameter TRIG_DELAY  = 500;     // 10us delay for trigger (50MHz / 500 = 100kHz)
    parameter DELAY_60_MS = 3000000; // 60ms delay (50MHz / 3000000 = 16.7Hz)
    
    // States
    localparam IDLE       = 3'b000;
    localparam SEND_PULSE = 3'b001;
    localparam WAIT_ECHO  = 3'b010;
    localparam MEASURE    = 3'b011;
    localparam WAIT_CYCLE = 3'b100;

	reg cycle_complete      = 0;
    reg [3:0] state         = IDLE;
    reg [21:0] counter      = 0;    // With 22 bits we can count up to 4.2 * 10^6 => 84 ms
    reg [32:0] echo_counter = 0;    // Used for counting microseconds echo has been high
    
    always@(posedge clk) begin
        counter <= cycle_complete? 0 : counter + 1;
    
        if(!rst) begin
            trig  <= 0;
            state <= IDLE;
        end else begin
            case(state) 
                IDLE: begin
					cycle_complete <= 0;
                    echo_counter <= 0; 
                    trig <= 1;
                    state <= SEND_PULSE;
                end
                SEND_PULSE: begin // Send input pulse to begin measuring
                    if(counter > TRIG_DELAY) begin // 10us Trigger pulse
                        trig  <= 0;
                        state <= WAIT_ECHO;
                    end
                end
                WAIT_ECHO: begin // Wait for echo to go high
                    if(echo) echo_counter <= echo_counter + 1; // Counting time elasped since echo has been high
                    else if (echo_counter) state <= MEASURE;
                end
                MEASURE: begin // Distance = Elapsed time (in us) echo has been high / 58
                    distance_cm <= echo_counter / 2900; // 2900 = 58*50. We divide by 50 since 50 cycles in 50MHz = 1 us
                    state <= WAIT_CYCLE;
                end
                WAIT_CYCLE: begin // Wait 60ms so measurements do not interfere with each other
                    if(counter > DELAY_60_MS) begin
                        cycle_complete <= 1;
						state <= IDLE;
					end
                end
					 
				default: state <= IDLE;
            endcase
        end
    end
endmodule