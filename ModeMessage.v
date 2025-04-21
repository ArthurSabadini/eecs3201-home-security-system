module ModeMessage (
    input [2:0] mode,
	input wire [3:0] msg,
    output reg [41:0] display
);
    // State Parameters
    parameter UNARM   =  3'b000;    // Display UNARM message
    parameter ARMS    =  3'b001;    // Display ARMS message
    parameter ARMA    =  3'b010;    // Display ARMA message
    parameter RESET   =  3'b011;    // Display RESET message
	parameter DISPLAY =  3'b100;    // Display a 4bit binary message (passcode)

    // Representation of Letters used
    localparam A    = 7'b0001000;
    localparam E    = 7'b0000110;
    localparam M1   = 7'b0101011; // Letter M needs two displays
	localparam M2   = 7'b0101011; // Letter M needs two displays
    localparam N    = 7'b1001000; 
    localparam R    = 7'b0101111;
    localparam S    = 7'b0010010;
    localparam T    = 7'b0000111;
    localparam U    = 7'b1000001;
    localparam OFF  = 7'b1111111;
	localparam ONE  = 7'b1111001;
	localparam ZERO = 7'b1000000;
    
    // Implementing as a Meeley Machine
    always@(mode or msg) begin
        case(mode)
            UNARM: begin
				display[41:35] <= U;
                display[34:28] <= N;
                display[27:21] <= A;
                display[20:14] <= R;
                display[13:7]  <= M1;
                display[6:0]   <= M2;
            end
            ARMS: begin
				display[41:35] <= A;
                display[34:28] <= R;
                display[27:21] <= M1;
                display[20:14] <= M2;
                display[13:7]  <= OFF;
                display[6:0]   <= S;
            end
            ARMA: begin
				display[41:35] <= A;
                display[34:28] <= R;
                display[27:21] <= M1;
                display[20:14] <= M2;
                display[13:7]  <= OFF;
                display[6:0]   <= A;
            end
            RESET: begin
				display[41:35] <= OFF;
                display[34:28] <= R;
                display[27:21] <= E;
                display[20:14] <= S;
                display[13:7]  <= E;
                display[6:0]   <= T;
            end
			DISPLAY: begin
				display[41:35] <= OFF;
                display[34:28] <= OFF;
                display[27:21] <= msg[0]? ZERO: ONE;
                display[20:14] <= msg[1]? ZERO: ONE;
                display[13:7]  <= msg[2]? ZERO: ONE;
                display[6:0]   <= msg[3]? ZERO: ONE;
				end
			default: begin
			    display[41:35] <= OFF;
                display[34:28] <= OFF;
                display[27:21] <= OFF;
                display[20:14] <= OFF;
                display[13:7]  <= OFF;
                display[6:0]   <= OFF;
		    end
        endcase
    end
endmodule