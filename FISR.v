//////////////////////////////////////////////////////////////////////////////////
// Company: Korea Univ. DIGITAL SYSTEM DESIGN AND LABORATORY
// Engineer: Jihyuk Park, Joon Seok Yun
// 
// Create Date: 2021/11/30 15:00:21
// Design Name: FISR_test
// Module Name: FISR
// Project Name: FISR_test
// Target Devices: HBE-Combo II-DLD
// Tool Versions: Vivado 2019
// Description: Specialized FPU for Fast Inverse Square Root Algorithm
// 
// Revision: Vivado Simulation Version
// Additional Comments:
// References:
// * https://github.com/dawsonjon/fpu
// * SevenSegentController - DIGITAL SYSTEM DESIGN AND LABORATORY
// * https://nybounce.wordpress.com/2016/06/24/
// * https://en.wikipedia.org/wiki/Fast_inverse_square_root
//
//////////////////////////////////////////////////////////////////////////////////
/*
-- 12/08
1. pin assignment error -> cleared by right assignment
2. button sensing problem -> solved by using prof's pulse generator module, inverted input with normal output
3. keypad input module problem -> rebuilt whole system as simple structure
4. error when '0' was input, 10th keyboard -> at output port, changed null to zero (00000000 to 11111100)
5. if put same number twice, module realizes it's same number (second input : turning off) -> means pulse gen runs well
things to do
1. shift input number to next segment port


-- 12/09
1. back to yesterday -> input with 'state' was a problem => solved with simple way, but don't know what's problem from 'state', Vivado ran well
2. made EOL (#) -> after pressing #, module gets no input
things to do
1. dot count after pressing dot


-- 12/15
1. complete the development of part modules
2. complete the main logic
things to do
1. DEC2BIN : add iDEC7 port. detail the accuracy.
2. FISR : include Processor module and develop global_state
*/

`define TRUE 1'b1
`define FALSE 1'b0

module FISR(
    input CLK, RST,
    input [11:0] keypad,
    output [7:0] oS_COM,
    output [7:0] oS_ENS,
	output reg [4:0] global_state
    );

    wire [11:0] filtered_keypad;
    wire [3:0] dot;
    wire [3:0] iDEC [7:0];
    wire [3:0] resDEC [7:0];

    reg [3:0] oDEC [7:0];
    reg [2:0] state = 0;
    reg [2:0] sub_state = 0;
    parameter   ready           = 3'd0,
                enable_CALCUL   = 3'd1,
                into_OUTPUT     = 3'd2;

    reg EN_CALCUL = 0;
    wire DONE_INPUT;
    wire DONE_CALCUL;
    wire [3:0] state_INPUT;
    wire [3:0] state_CALCUL;

    DigitalFilterCircuit DFC(.CLK(CLK), .RST(RST), .iKeypad(keypad), .oKeypad(filtered_keypad));

	
    KeypadInput INPUT(  .CLK(CLK), .RST(RST), .keypad(filtered_keypad),  
                        .oDEC7(iDEC[7]), .oDEC6(iDEC[6]), .oDEC5(iDEC[5]), .oDEC4(iDEC[4]), 
                        .oDEC3(iDEC[3]), .oDEC2(iDEC[2]), .oDEC1(iDEC[1]), .oDEC0(iDEC[0]),
                        .state(state_INPUT), .DONE(DONE_INPUT), .dot(dot));		
    
    Processor   CALCUL( .CLK(CLK), .RST(RST), .dot(dot), .EN(EN_CALCUL),
                        .iDEC6(iDEC[6]), .iDEC5(iDEC[5]), .iDEC4(iDEC[4]), .iDEC3(iDEC[3]), .iDEC2(iDEC[2]), .iDEC1(iDEC[1]), .iDEC0(iDEC[0]),
                        .oDEC7(resDEC[7]), .oDEC6(resDEC[6]), .oDEC5(resDEC[5]), .oDEC4(resDEC[4]), .oDEC3(resDEC[3]), .oDEC2(resDEC[2]), .oDEC1(resDEC[1]), .oDEC0(resDEC[0]),
                        .state(state_CALCUL), .DONE(DONE_CALCUL));

    SegmentOutput OUTPUT(.CLK(CLK), .RST(RST),
                        .iDEC7(oDEC[7]), .iDEC6(oDEC[6]), .iDEC5(oDEC[5]), .iDEC4(oDEC[4]), 
                        .iDEC3(oDEC[3]), .iDEC2(oDEC[2]), .iDEC1(oDEC[1]), .iDEC0(oDEC[0]),
                        .oS_COM(oS_COM), .oS_ENS(oS_ENS));

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            global_state <= 0;
            state <= ready; sub_state <= 0;
            EN_CALCUL <= `FALSE;
        end

        case (state)
            ready: 
            begin
                global_state <= state_INPUT;
                // global_state <= 1;

                oDEC[7] <= iDEC[7]; oDEC[6] <= iDEC[6]; oDEC[5] <= iDEC[5]; oDEC[4] <= iDEC[4]; 
                oDEC[3] <= iDEC[3]; oDEC[2] <= iDEC[2]; oDEC[1] <= iDEC[1]; oDEC[0] <= iDEC[0]; 

                if (DONE_INPUT) state <= enable_CALCUL;
            end

            enable_CALCUL:
            begin
                global_state <= state_CALCUL;
                // global_state <= 2;

                case (sub_state)
                    0: 
                    begin
                        EN_CALCUL <= `TRUE;
                        sub_state <= sub_state + 1;
                    end
                    1:
                    begin
                        EN_CALCUL <= `FALSE;
                        if (DONE_CALCUL) begin 
                            state <= into_OUTPUT;
                            sub_state <= 0;
                        end
                    end
                endcase
            end

            into_OUTPUT:
            begin
                global_state <= 16;
                // global_state <= 3;
                oDEC[7] <= resDEC[7]; oDEC[6] <= resDEC[6]; oDEC[5] <= resDEC[5]; oDEC[4] <= resDEC[4]; 
                oDEC[3] <= resDEC[3]; oDEC[2] <= resDEC[2]; oDEC[1] <= resDEC[1]; oDEC[0] <= resDEC[0]; 
            end
        endcase
    end
	
    

endmodule

module Processor (
    input CLK, RST,
    input [3:0] dot,
    input EN,
    input [3:0] iDEC6, iDEC5, iDEC4, iDEC3, iDEC2, iDEC1, iDEC0,
    output [3:0] oDEC7, oDEC6, oDEC5, oDEC4, oDEC3, oDEC2, oDEC1, oDEC0,
    output reg DONE,
    output reg [3:0] state,
    output reg [31:0] result
    );

    /*
        float Q_rsqrt( float number )    {
            long i;
            float x2, y;
            const float threehalfss = 1.5F;

            x2 = number * 0.5F;
            y = number;
            i = * ( long * ) &y; // transform from BIN to IEEE754
            i = 0x5f3759df - ( i >> 1 ); // shift bits and subtract as bits
            y = * ( float * ) &i; // ignore 
            y = y * ( threehalfss - ( x2 * y * y ) ); // mul and sub as IEEE754(float32)
        
            return y; // transform from IEEE754 to BIN
        }
    ---------------------------------------------------------------------------------------
        Processor {
            reg [31:0] number (IEEE) <= input (BIN)
            reg [31:0] half (IEEE) <= 0.5 (BIN)
            reg [31:0] threehalfss (IEEE) <= 1.5 (BIN)
            reg [31:0] x2 <= number * half (float32_mul)
            reg [31:0] y <= 0x5f3759df - number >> 1
            reg [31:0] x2y <= x2 * y (float32_mul)
            reg [31:0] x2yy <= x2y * y (float32_mul)
            reg [31:0] newton_iter <= threehalfss - x2yy (float32_add)
            reg [31:0] result <= y * sub (float32_mul)
        }
    */
    // reg [3:0] state = 0; moved to output port
    reg [3:0] sub_state = 0;

    parameter   magic_number = 32'h5f3759df;
    parameter   ready                   = 4'd0,
                get_input               = 4'd1,
                get_variable_HALF       = 4'd2,
                get_variable_THREEHALFS = 4'd3,
                calc_x2                 = 4'd4,
                calc_y                  = 4'd5,
                calc_x2y                = 4'd6,
                calc_x2yy               = 4'd7,
                subtract                = 4'd8,
                multiply                = 4'd9,
                convert_to_BIN          = 4'd10,
                convert_to_DEC          = 4'd11,
                done                    = 4'd12;
    
    reg EN_U0 = `FALSE;
    reg EN_U1 = `FALSE;
    reg EN_U2 = `FALSE;
    reg EN_U3 = `FALSE;
    reg EN_U4 = `FALSE;
    reg EN_U5 = `FALSE;
    wire DONE_U0;
    wire DONE_U1;
    wire DONE_U2;
    wire DONE_U3;
    wire DONE_U4;
    wire DONE_U5;
    
    reg [22:0] iBIN1, iBIN0;
    reg [31:0] input_a, input_b;
    reg [22:0] result_BIN1, result_BIN0;

    wire [22:0] oBIN1, oBIN0;
    wire [31:0] output_z_mul, output_z_add;
    wire [22:0] w_result_BIN1, w_result_BIN0;

    wire [31:0] w_number;
    reg [31:0] number;
    reg [31:0] half;
    reg [31:0] threehalfs;
    reg [31:0] x2, y, x2y, x2yy, newton_iter;// result;

    DEC2BIN U0( .CLK(CLK), .RST(RST), .dot(dot), .EN(EN_U0), 
                .DEC6(iDEC6), .DEC5(iDEC5), .DEC4(iDEC4), .DEC3(iDEC3), .DEC2(iDEC2), .DEC1(iDEC1), .DEC0(iDEC0),
                .oBIN1(oBIN1), .oBIN0(oBIN0), .DONE(DONE_U0), .state(/**/));

    BIN2IEEE U1(.CLK(CLK), .RST(RST), .EN(EN_U1),
                .BIN1(iBIN1), .BIN0(iBIN0),
                .IEEE(w_number), .DONE(DONE_U1));

    float32_add U2( .CLK(CLK), .RST(RST), .EN(EN_U2), .input_a(input_a), .input_b(input_b), .output_z(output_z_add), .DONE(DONE_U2));


    float32_mul U3( .CLK(CLK), .RST(RST), .EN(EN_U3), .input_a(input_a), .input_b(input_b), .output_z(output_z_mul), .DONE(DONE_U3));

    IEEE2BIN U4(.CLK(CLK), .RST(RST), .EN(EN_U4),
                .IEEE(result),
                .BIN1(w_result_BIN1), .BIN0(w_result_BIN0), .DONE(DONE_U4));

    BIN2DEC U5( .CLK(CLK), .RST(RST), .EN(EN_U5),
                .BIN1(result_BIN1), .BIN0(result_BIN0),
                .DEC7(oDEC7), .DEC6(oDEC6), .DEC5(oDEC5), .DEC4(oDEC4), .DEC3(oDEC3), .DEC2(oDEC2), .DEC1(oDEC1), .DEC0(oDEC0),
                .DONE(DONE_U5));


    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            state <= ready;
            sub_state <= 0;
            DONE <= `FALSE;
            EN_U0 = `FALSE;
            EN_U1 = `FALSE;
            EN_U2 = `FALSE;
            EN_U3 = `FALSE;
            EN_U4 = `FALSE;
            EN_U5 = `FALSE;
        end

        case (state)
            ready: 
            begin
                if (EN)  state <= get_input;
                else     state <= ready;
            end

            get_input:
            begin
                case (sub_state)
                    0: // step1. enable DEC2BIN
                    begin
                        EN_U0 <= `TRUE;
                        sub_state <= sub_state + 1;
                    end
                    1: // step2. disable DEC2BIN
                    begin
                        EN_U0 <= `FALSE;
                        sub_state <= sub_state + 1;
                    end
                    2: // step3. if DEC2BIN is done, enable BIN2IEEE
                    begin
                        if (DONE_U0) begin
                            iBIN1 <= oBIN1;
                            iBIN0 <= oBIN0;
                            EN_U1 <= `TRUE;
                            sub_state <= sub_state + 1;
                        end
                    end
                    3: // step4. disable BIN2IEEE, and get converted input as number
                    begin
                        EN_U1 <= `FALSE;
                        if (DONE_U1) begin
                            number <= w_number;
                            state <= get_variable_HALF;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end

            get_variable_HALF:
            begin
                case (sub_state)
                    0: // enable BIN2IEEE
                    begin
                        EN_U1 <= `TRUE;
                        iBIN1 <= 23'b0; 
                        iBIN0 <= {1'b1, 22'b0}; // 0.5 (decimal) == 0.1 (binary) 
                        sub_state <= sub_state + 1;
                    end 
                    1: // disable BIN2IEEE, and get converted variable 'half'
                    begin
                        EN_U1 <= `FALSE;
                        if (DONE_U1) begin
                            half <= w_number;
                            state <= get_variable_THREEHALFS;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase               
            end


            get_variable_THREEHALFS:
            begin
                case (sub_state)
                    0: // enable BIN2IEEE
                    begin
                        EN_U1 <= `TRUE;
                        iBIN1 <= {22'b0, 1'b1}; 
                        iBIN0 <= {1'b1, 22'b0}; // 1.5 (decimal) == 1.1 (binary)
                        sub_state <= sub_state + 1;
                    end
                    1: // disable BIN2IEEE, and get converted variable 'threehalfs'
                    begin
                        EN_U1 <= `FALSE;
                        if (DONE_U1) begin
                            threehalfs <= w_number;
                            state <= calc_x2;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end
            
            calc_x2:
            begin
                case (sub_state)
                    0: // enable float32_mul
                    begin
                        EN_U3 <= `TRUE;
                        input_a <= number; 
                        input_b <= half; // x2 = number * half
                        sub_state <= sub_state + 1;
                    end 
                    1: // disabel float32_mul, and get the multiplied variable x2
                    begin
                        EN_U3 <= `FALSE;
                        if (DONE_U3) begin
                            x2 <= output_z_mul;
                            state <= calc_y;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end

            calc_y:
            begin
                y <= magic_number - (number >> 1);
                state <= calc_x2y;
            end

            calc_x2y:
            begin
                case (sub_state)
                    0: // enable float32_mul
                    begin
                        EN_U3 <= `TRUE;
                        input_a <= x2; 
                        input_b <= y; // x2y = x2 * y
                        sub_state <= sub_state + 1;
                    end 
                    1: // disabel float32_mul, and get the multiplied variable x2y
                    begin
                        EN_U3 <= `FALSE;
                        if (DONE_U3) begin
                            x2y <= output_z_mul;
                            state <= calc_x2yy;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end

            calc_x2yy:
            begin
                case (sub_state)
                    0: // enable float32_mul
                    begin
                        EN_U3 <= `TRUE;
                        input_a <= x2y; 
                        input_b <= y; // x2yy = x2y * y
                        sub_state <= sub_state + 1;
                    end 
                    1: // disabel float32_mul, and get the multiplied variable x2yy
                    begin
                        EN_U3 <= `FALSE;
                        if (DONE_U3) begin
                            x2yy <= output_z_mul;
                            state <= subtract;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end

            subtract:
            begin
                case (sub_state)
                    0:
                    begin
                        EN_U2 <= `TRUE;
                        input_a <= threehalfs;
                        input_b <= {1'b1, x2yy[30:0]}; // minus x2yy
                        sub_state <= sub_state + 1;
                    end
                    1:
                    begin
                        EN_U2 <= `FALSE;
                        if (DONE_U2) begin
                            newton_iter <= output_z_add; // subtraction part of newton iteration
                            state <= multiply;
                            sub_state <= 0;
                        end
                    end
                endcase
            end

            multiply:
            begin
                case (sub_state)
                    0: // enable float32_mul
                    begin
                        EN_U3 <= `TRUE;
                        input_a <= y; 
                        input_b <= newton_iter; // newton_iter = y * ( threehalfs - ( x2 * y * y ) )
                        sub_state <= sub_state + 1;
                    end 
                    1: // disabel float32_mul, and get the multiplied variable 
                    begin
                        EN_U3 <= `FALSE;
                        if (DONE_U3) begin
                            result <= output_z_mul; // result in IEEE form
                            state <= convert_to_BIN;
                            sub_state <= 0; // clear sub_state
                        end
                    end
                endcase
            end

            convert_to_BIN:
            begin
                case (sub_state)
                    0: 
                    begin
                        EN_U4 <= `TRUE;
                        sub_state <= sub_state + 1;
                    end
                    1:
                    begin
                        EN_U4 <= `FALSE;
                        if (DONE_U4) begin
                            result_BIN1 <= w_result_BIN1;
                            result_BIN0 <= w_result_BIN0;
                            state <= convert_to_DEC;
                            sub_state <= 0;
                        end
                    end
                endcase
            end

            convert_to_DEC:
            begin
                EN_U5 <= `TRUE;
                if (DONE_U5)
                    DONE <= `TRUE;
            end

        endcase
    end

endmodule


module pulse_gen(input clk, input reset, input signal, output pulse);

        reg [3:0] c_state;  // current state
        reg [3:0] n_state;  // next state

        parameter  S0  =  4'b0000;
        parameter  S1  =  4'b0001;
        parameter  S2  =  4'b0010;
        parameter  S3  =  4'b0011;
        parameter  S4  =  4'b0100;
        parameter  S5  =  4'b0101;
        parameter  S6  =  4'b0110;
        parameter  S7  =  4'b0111;
        parameter  S8  =  4'b1000;
        parameter  S9  =  4'b1001;
        parameter  S10 =  4'b1010;
        parameter  S11 =  4'b1011;
        parameter  S12 =  4'b1100;
        parameter  S13 =  4'b1101;
        parameter  S14 =  4'b1110;
        parameter  S15 =  4'b1111;

        always@ (posedge clk) // synchronous resettable flop-flops
        begin
            if(!reset)	c_state <= S0;
            else		c_state <= n_state;
        end
        
        always@(*) // Next state logic
        begin
        case(c_state)
        S0 : 	if(~signal)	n_state <= S1;
                else	    n_state <= S0;

        S1 : 	if(~signal) n_state <= S2;
                else 		n_state <= S0;

        S2 : 	if(~signal)	n_state <= S3;
                else		n_state <= S0;

        S3 : 	if(~signal) n_state <= S4;
                else		n_state <= S0;

        S4 : 	if(~signal)	n_state <= S5;
                else		n_state <= S0;

        S5 : 	if(~signal) n_state <= S6;
                else		n_state <= S0;

        S6 : 	if(~signal)	n_state <= S7;
                else		n_state <= S0;

        S7 : 	if(~signal) n_state <= S8;
                else		n_state <= S0;

        S8 :	if(~signal)	n_state <= S9;
                else		n_state <= S0;

        S9 : 	if(~signal)	n_state <= S10;
                else		n_state <= S0;

        S10: 	if(~signal)	n_state <= S11;
                else		n_state <= S0;

        S11: 	if(~signal)	n_state <= S12;
                else		n_state <= S0;

        S12:	if(~signal) n_state <= S13;
                else 		n_state <= S0;

        S13: 	if(~signal) n_state <= S14;
                else		n_state <= S0;

        S14:	if(~signal) n_state <= S15;
                else		n_state <= S0;

        S15: 	if(signal)	n_state <= S0;
                else		n_state <= S15;
                    
        default:       		n_state <= S0;
        endcase
    end

    assign  pulse = (c_state == S14);

endmodule

module DigitalFilterCircuit (
    input CLK, RST,
    input [11:0] iKeypad,
    output [11:0] oKeypad
    );

    pulse_gen sw0 (CLK, RST, ~iKeypad[0], oKeypad[0]);
    pulse_gen sw1 (CLK, RST, ~iKeypad[1], oKeypad[1]);
    pulse_gen sw2 (CLK, RST, ~iKeypad[2], oKeypad[2]);
    pulse_gen sw3 (CLK, RST, ~iKeypad[3], oKeypad[3]);
    pulse_gen sw4 (CLK, RST, ~iKeypad[4], oKeypad[4]);
    pulse_gen sw5 (CLK, RST, ~iKeypad[5], oKeypad[5]);
    pulse_gen sw6 (CLK, RST, ~iKeypad[6], oKeypad[6]);
    pulse_gen sw7 (CLK, RST, ~iKeypad[7], oKeypad[7]);
    pulse_gen sw8 (CLK, RST, ~iKeypad[8], oKeypad[8]);
    pulse_gen sw9 (CLK, RST, ~iKeypad[9], oKeypad[9]);
    pulse_gen sw10 (CLK, RST, ~iKeypad[10], oKeypad[10]);
    pulse_gen sw11 (CLK, RST, ~iKeypad[11], oKeypad[11]);

endmodule


module KeypadInput (
    input CLK, RST,
    input [11:0] keypad,
    output [3:0] oDEC7, oDEC6, oDEC5, oDEC4, oDEC3, oDEC2, oDEC1, oDEC0,
	output reg [2:0] state,
    output reg DONE,
    output reg [3:0] dot
    );
    
    parameter   ready = 3'd0,
                done = 3'd1;

    reg [3:0] DEC [7:0]; // DEC 메모리
    reg [2:0] dot_count;
    reg start_dot_count;
	 
    initial begin 
        DONE = `FALSE;
        dot_count <= 3'b000; start_dot_count = `FALSE; dot <= 0;
        
        DEC[7] <= 0; DEC[6] <= 0; DEC[5] <= 0; DEC[4] <= 0; 
        DEC[3] <= 0; DEC[2] <= 0; DEC[1] <= 0; DEC[0] <= 0;

        state <= ready;
    end

    /*
    1. input reg shift condition : when keypad = 0 -> keypad != 0, shift all the arrays, and store input number in input_reg.
    2. terminal condition : when input_reg = 12, stop getting input. signal EN
    3. dot point condition : 
    */
	 always @(posedge CLK or negedge RST) begin
        if(!RST) begin
            DONE = `FALSE;
            dot_count <= 3'b000; start_dot_count = `FALSE; dot <= 0;

            DEC[7] <= 0; DEC[6] <= 0; DEC[5] <= 0; DEC[4] <= 0; 
            DEC[3] <= 0; DEC[2] <= 0; DEC[1] <= 0; DEC[0] <= 0;
            
            state <= ready; 
        end
        else begin
            case(state)
            
            ready:
            begin
                if(keypad) begin
                    if (start_dot_count) begin
                        dot_count <= dot_count + 1;
                    end
                

                    case(keypad) 
                    12'b0000_0000_0001: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 1;
                        state <= ready;
                    end
                    12'b0000_0000_0010: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 2;
                        state <= ready;
                    end
                    12'b0000_0000_0100: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 3;
                        state <= ready;
                    end
                    12'b0000_0000_1000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 4;
                        state <= ready;
                    end
                    12'b0000_0001_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 5;
                        state <= ready;
                    end
                    12'b0000_0010_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 6;
                        state <= ready;
                    end
                    12'b0000_0100_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 7;
                        state <= ready;
                    end
                    12'b0000_1000_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 8;
                        state <= ready;
                    end
                    12'b0001_0000_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 9;
                        state <= ready;
                    end
                    12'b0010_0000_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 10; // *
                        state <= ready;
                        start_dot_count <= `TRUE;
                    end
                    12'b0100_0000_0000: begin
                        {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1]} <= 
                        {DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};
                        DEC[0] <= 0; // 0
                        state <= ready;
                    end
                    12'b1000_0000_0000: begin
                        state <= done; // #, EOL
                    end
                    endcase
                end
            end
            
            done:
            begin
                DONE <= `TRUE;

                    case (dot_count)
                        1: dot <= 4'b0000; // means the position of dot point.
                        2: dot <= 4'b0010;
                        3: dot <= 4'b0100;
                        4: dot <= 4'b1000;
                        default: dot <= 4'b0000;
                    endcase
            end
            endcase
        end
	 end
	 

    assign {oDEC7, oDEC6, oDEC5, oDEC4, oDEC3, oDEC2, oDEC1, oDEC0} 
    = {DEC[7], DEC[6], DEC[5], DEC[4], DEC[3], DEC[2], DEC[1], DEC[0]};

endmodule


module DEC2BIN (
    input CLK, RST,
    input [3:0] dot,
    input EN,
    input [3:0] DEC6, DEC5, DEC4, DEC3, DEC2, DEC1, DEC0,
    output reg [22:0] oBIN1, oBIN0, // integer part, fractional part
    output reg DONE,
    output reg [3:0] state
    );

    // reg [3:0] state;
    parameter   ready = 4'd0,
                get_dec = 4'd1,
                dec_to_int = 4'd2,
                int_to_float = 4'd3,
                put_bin = 4'd4;

    reg [3:0] DEC [6:0];
    reg [22:0] BIN1, BIN0; // integer part, fractional part

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            DEC[6] <= 0; DEC[5] <= 0; DEC[4] <= 0;
            DEC[3] <= 0; DEC[2] <= 0; DEC[1] <= 0; DEC[0] <= 0;
            BIN1 <= 0; BIN0 <= 0;
            DONE <= `FALSE;

            state <= ready;
        end

        case (state)
            ready:
            begin
                if (EN)  state <= get_dec;
                else     state <= ready;

                DONE <= `FALSE;
            end

            get_dec:
            begin
                DEC[6] <= DEC6; DEC[5] <= DEC5; DEC[4] <= DEC4;
                DEC[3] <= DEC3; DEC[2] <= DEC2; DEC[1] <= DEC1; DEC[0] <= DEC0;
                BIN1 <= 0; BIN0 <= 0;
                DONE <= `FALSE;

                state <= dec_to_int;
            end 

            dec_to_int:
            begin
                case (dot)
                    4'b1000: begin
                        //integer part: 3 digits
                        BIN1 <= DEC[4] +
                                DEC[5] * 10 +
                                DEC[6] * 100;

                        //fractional part: 3 digits
                        BIN0 <= DEC[2] * 100 +
                                DEC[1] * 10 + 
                                DEC[0];
                        
                        state <= int_to_float;
                    end
                    4'b0100: begin
                        //integer part: 4 digits
                        BIN1 <= DEC[3] +
                                DEC[4] * 10 + 
                                DEC[5] * 100 +
                                DEC[6] * 1000;
                        
                        //fractional part: 2 digits
                        BIN0 <= DEC[1] * 100 +
                                DEC[0] * 10;
                        
                        state <= int_to_float;
                    end
                    4'b0010: begin
                        // integer part: 5 digits
                        BIN1 <= DEC[2] +
                                DEC[3] * 10 +
                                DEC[4] * 100 +
                                DEC[5] * 1000 +
                                DEC[6] * 10000;

                        // fractional part: 1 digits
                        BIN0 <= DEC[0] * 100;

                        state <= int_to_float;
                    end
                    4'b0000: begin
                        // integer part: All 6 digits
                        BIN1 <= DEC[0] +
                                DEC[1] * 20'd10 +
                                DEC[2] * 20'd100 +
                                DEC[3] * 20'd1000 +
                                DEC[4] * 20'd10000 +
                                DEC[5] * 20'd100000 + 
                                DEC[6] * 20'd1000000; 
                        
                        state <= put_bin;
                    end 
                    default: begin 
                        BIN1 <= 0; BIN0 <= 0; 
                    end
                endcase
            end

            int_to_float:
            begin
                BIN0 <= (BIN0 << 4'd13);

                state <= put_bin;
            end

            put_bin:
            begin
                oBIN0 <= BIN0;
                oBIN1 <= BIN1;

                DONE <= `TRUE;
                state <= ready;
            end
                
        endcase
    end

endmodule
    
module BIN2IEEE (
    input CLK, RST,
    input EN,
    input [22:0] BIN1, BIN0,
    output reg [31:0] IEEE,
    output reg DONE
    );

    reg [3:0] state;
    parameter   ready = 4'd0,
                get_input = 4'd1,
                compare_size = 4'd2,
                get_exp_from_BIN1 = 4'd3, // 정수부
                get_exp_from_BIN0 = 4'd4, // 소수부
                zero_case = 4'd5,
                put_IEEE = 4'd6;

    reg [1:0] forLoopState;
    parameter   forLoop = 1'b0,
                exit = 1'b1;

    reg [4:0] count = 1;
    reg [22:0] reg_BIN1, reg_BIN0;
    reg [22:0] temp_BIN1, temp_BIN0;
    reg [45:0] merge;
    reg [22:0] mantissa;
    reg [7:0] exp;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            count <= 1;
            reg_BIN1 <= 0; reg_BIN0 <= 0;
            temp_BIN1 <= 0; temp_BIN0 <= 0;
            merge <= 0;
            mantissa <= 0;
            exp <= 0;
            DONE <= `FALSE;

            forLoopState <= 0;
            state <= ready;
        end

        case (state)
            ready:
            begin
                count <= 1;
                reg_BIN1 <= 0; reg_BIN0 <= 0;
                temp_BIN1 <= 0; temp_BIN0 <= 0;
                merge <= 0;
                mantissa <= 0;
                exp <= 0;
                DONE <= `FALSE;

                forLoopState <= 0;
                if (EN)  state <= get_input;
                else     state <= ready;
            end

            get_input:
            begin
                reg_BIN1 <= BIN1; reg_BIN0 <= BIN0;
                state <= compare_size;
            end

            compare_size:
            begin
                temp_BIN1 <= reg_BIN1;
                temp_BIN0 <= reg_BIN0;

                if (reg_BIN1)       state <= get_exp_from_BIN1;
                else if (reg_BIN0)  state <= get_exp_from_BIN0;
                else            state <= zero_case;
            end 
            
            get_exp_from_BIN1:
            begin
                case (forLoopState)
                    forLoop:
                    begin
                        // terminate condition
                        if (temp_BIN1[22] == 1)  forLoopState <= exit;
                        // for loop
                        else begin
                            temp_BIN1 <= (temp_BIN1 << 1);
                            count <= count + 1;
                            forLoopState <= forLoop;
                        end
                    end 
                    exit:
                    begin
                        exp <= (23 - count) + 127;

                        // merge <= ({BIN1, BIN0} << count)
                        // merge <= merge[45:23]
                        // mantissa <= merge
                        mantissa <= ({reg_BIN1, reg_BIN0} << count) >> 23;

                        state <= put_IEEE;
                    end
                endcase
            end
            

            get_exp_from_BIN0:
            begin
                case (forLoopState)
                    forLoop:
                    begin
                        // terminate condition
                        if (temp_BIN0[22] == 1)  forLoopState <= exit;
                        // for loop
                        else begin
                            temp_BIN0 <= (temp_BIN0 << 1);
                            count <= count + 1;
                            forLoopState <= forLoop;
                        end
                    end 
                    exit:
                    begin
                        exp <= -count + 127;

                        mantissa <= (reg_BIN0 << count);

                        state <= put_IEEE;
                    end
                endcase
            end

            zero_case:
            begin
                exp <= 0;
                mantissa <= 0;

                state <= put_IEEE;
            end

            put_IEEE:
            begin
                IEEE <= {1'b0, exp, mantissa};
                DONE <= `TRUE;
                state <= ready;
            end
            
        endcase
    end

endmodule


module IEEE2BIN (
    input CLK, RST,
    input EN,
    input [31:0] IEEE,
    output reg [22:0] BIN1, BIN0,
    output reg DONE
    );

    reg [3:0] state;
    parameter  ready = 4'd0,
                separate_IEEE = 4'd1,
                get_count = 4'd2,
                BIN1_exist = 4'd3,
                BIN1_not_exist = 4'd4,
                done = 4'd5;

    reg [4:0] count;
    reg [22:0] mantissa;
    reg [7:0] exp;
    reg sign;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            count <= 0;
            mantissa <= 0; exp <= 0; sign <= 0;
            DONE <= `FALSE;

            state <= ready;
        end

        case (state)
            ready:
            begin
                count <= 0;
                mantissa <= 0; exp <= 0; sign <= 0;
                DONE <= `FALSE;

                if (EN)  state <= separate_IEEE;
                else                  state <= ready;
            end
            
            separate_IEEE:
            begin
                if (IEEE != 0) begin
                    sign <= IEEE[31];
                    exp <= IEEE[30:23];
                    mantissa <= IEEE[22:0];
                    state <= get_count;
                end
                else begin
                    BIN1 <= 0; BIN0 <= 0;
                    state <= done;
                end
            end
            
            get_count:
            begin
                if (exp >= 127) begin
                    count <= exp - 126;
                    state <= BIN1_exist;
                end
                else begin
                    count <= 127 - exp;
                    state <= BIN1_not_exist;
                end
            end
            
            BIN1_exist:
            begin
                BIN1 <=  ({22'b0, 1'b1, mantissa} << count) >> 24;
                BIN0 <= ({22'b0, 1'b1, mantissa} << count - 1);
                state <= done;
            end
            
            BIN1_not_exist:
            begin
                BIN1 <= 0;
                BIN0 <= ({22'b0, 1'b1, mantissa} >> count);
                state <= done;
            end
            
            done:
            begin
                DONE <= `TRUE;
                state <= ready;
            end
            
        endcase
    end

endmodule


module BIN2DEC (
    input CLK, RST,
    input EN,
    input [22:0] BIN1, BIN0,
    output reg [3:0] DEC7, DEC6, DEC5, DEC4, DEC3, DEC2, DEC1, DEC0,
    output reg DONE
    );

    reg [3:0] state;
    parameter  ready = 4'd0,
                into_dec = 4'd1,
                get_int = 4'd2,
                get_fraction = 4'd3,
                get_dec = 4'd4;
    
    reg [7:0] temp_int;
    reg [23:0] temp_fraction;
    reg [7:0] dot;
    
    reg [7:0] int;
    reg [29:0] fraction;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            dot <= 0;
            DEC7 <= 0; DEC6 <= 0; DEC5 <= 0; DEC4 <= 0;
            DEC3 <= 0; DEC2 <= 0; DEC1 <= 0; DEC0 <= 0;

            DONE <= `FALSE;
            state <= ready;
        end

        case (state)
            ready:
            begin
                if (EN)  state <= into_dec;
                else                       state <= ready;
                DONE <= `FALSE;
            end
            
            into_dec:
            begin
                int <= BIN1[0] * 1 + BIN1[1] * 2 + BIN1[2] * 4 + BIN1[3] * 8 + 
                       BIN1[4] * 16 + BIN1[5] * 32 + BIN1[6] * 64;
                fraction <= BIN0[22] * 5_0000_0000 + BIN0[21] * 2_5000_0000 + BIN0[20] * 1_2500_0000 + BIN0[19] * 6250_0000 +
                            BIN0[18] * 3125_0000 + BIN0[17] * 1562_5000 + BIN0[16] * 781_2500 + BIN0[15] * 390_6250 +
                            BIN0[14] * 195_3125 + BIN0[13] * 97_6563 + BIN0[12] * 48_8281 + BIN0[11] * 24_4141 +
                            BIN0[10] * 12_2070 + BIN0[9] * 6_1035 + BIN0[8] * 3_0518 + BIN0[7] * 1_5259 + BIN0[6] * 7630 +
                            BIN0[5] * 3815 + BIN0[4] * 1907 + BIN0[3] * 954 + BIN0[2] * 477 + BIN0[1] * 238 + BIN0[0] * 119;
                state <= get_int;
            end

            get_int:
            if (BIN1 != 0) begin
                temp_int [3:0] <= int % 10;
                temp_int [7:4] <= int / 10;
                state <= get_fraction;
            end
            else
            begin
                temp_int <= 0;
                state <= get_fraction;
            end 
            
            get_fraction:
            begin
                if (temp_int == 0) begin
                    dot <= 8'b01000000;
                    temp_fraction[23:20] <= fraction / 1_0000_0000;
                    temp_fraction[19:16] <= (fraction % 1_0000_0000) / 1000_0000;
                    temp_fraction[15:12] <= (fraction % 1000_0000) / 100_0000;
                    temp_fraction[11:8] <= (fraction % 100_0000) / 10_0000;
                    temp_fraction[7:4] <= (fraction % 10_0000) / 1_0000;
                    temp_fraction[3:0] <= (fraction % 1_0000) / 1000;
                    state <= get_dec;
                end
                else begin
                    if (temp_int[7:4] != 0) begin
                        dot <= 8'b00100000;
                        temp_fraction[23:20] <= fraction / 1_0000_0000;
                        temp_fraction[19:16] <= (fraction % 1_0000_0000) / 1000_0000;
                        temp_fraction[15:12] <= (fraction % 1000_0000) / 100_0000;
                        temp_fraction[11:8] <= (fraction % 100_0000) / 10_0000;
                        temp_fraction[7:4] <= (fraction % 10_0000) / 1_0000;
                        state <= get_dec;
                    end
                    else begin
                        dot <= 8'b01000000;
                        temp_fraction[23:20] <= fraction / 1_0000_0000;
                        temp_fraction[19:16] <= (fraction % 1_0000_0000) / 1000_0000;
                        temp_fraction[15:12] <= (fraction % 1000_0000) / 100_0000;
                        temp_fraction[11:8] <= (fraction % 100_0000) / 10_0000;
                        temp_fraction[7:4] <= (fraction % 10_0000) / 1_0000;
                        temp_fraction[3:0] <= (fraction % 1_0000) / 1000;
                        state <= get_dec;
                    end
                end
            end
            
            get_dec:
            begin
                case(dot)
                    8'b01000000: begin
                        DEC7 <= temp_int[3:0];
                        DEC6 <= 10;
                        DEC5 <= temp_fraction[23:20];
                        DEC4 <= temp_fraction[19:16];
                        DEC3 <= temp_fraction[15:12];
                        DEC2 <= temp_fraction[11:8];
                        DEC1 <= temp_fraction[7:4];
                        DEC0 <= temp_fraction[3:0];
                    end
                    8'b00100000: begin
                        DEC7 <= temp_int[7:4];
                        DEC6 <= temp_int[3:0];
                        DEC5 <= 10;
                        DEC4 <= temp_fraction[23:20];
                        DEC3 <= temp_fraction[19:16];
                        DEC2 <= temp_fraction[15:12];
                        DEC1 <= temp_fraction[11:8];
                        DEC0 <= temp_fraction[7:4];
                    end
                endcase

                DONE <= `TRUE;
                state <= ready;
            end                
        endcase
    end

endmodule 


module float32_add (
    input CLK, RST, EN,
    input [31:0] input_a, input_b,
    output reg [31:0] output_z,
    output reg DONE
    );

    reg [3:0] state;
    parameter   ready         = 4'd0,
                get_input     = 4'd1,
                unpack        = 4'd2,
                special_cases = 4'd3,
                align         = 4'd4,
                add_0         = 4'd5,
                add_1         = 4'd6,
                normalise_1   = 4'd7,
                normalise_2   = 4'd8,
                round         = 4'd9,
                pack          = 4'd10,
                put_z         = 4'd11;

    reg [31:0] a, b, z;
    reg [26:0] a_man, b_man;
    reg [23:0] z_man;
    reg [9:0] a_exp, b_exp, z_exp;
    reg a_sign, b_sign, z_sign;
    reg guard, round_bit, sticky;
    reg [27:0] sum;

    /*
    * NaN : 
        NaN은 연산과정에서 잘못된 입력(inf+inf, 0/0)을 받아 계산을 하지 못했음을 나타내는 기호
        지수부(exponent)의 모든 bit는 1로 채운다.
        가수부(mantisa)의 값은 0이 아니어야 한다.
        부호부(sign)은 의미를 두지 않는다.
    * inf :
        overflow가 발생하였을때 표현하는 값을 정의한다.
        지수부(exponent)의 모든 bit는 1로 채운다.
        가수부(mantisa)의 모든 bit는 0으로 채운다.
        부호부(sign)에 따라 양의 무한대와 음의 무한대로 구분된다.
    * signed zero :
        IEEE 754에서는 부호가 있는 0을 구분하고 있다.
        단 if (x == 0)과 같은 작업에서 불확실한 결과를 낼 수 있기 때문에 -0 = +0 이라는 규칙을 정해놓았다.
        지수부(exponent)의 모든 bit는 0으로 채운다.
        가수부(mantisa)의 모든 bit 역시 0으로 채운다.
        부호부(sign)에 따라 +0 과 -0으로 구분된다.
    * denormalized :
        1.00 x 2^(-126) 보다 작아 표현 불가능한 수
        지수부(exponent)의 모든 bit는 0으로 채운다.
        부호부(sign)와 가수부(matisa)의 값을 표현한다
    */

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            state <= ready;
            // Write initialization code here
            output_z <= 0;
            DONE <= `FALSE;
        end
        
        case (state)
            ready:
            begin
                if (EN) state <= get_input;
                else    state <= ready;
                DONE <= `FALSE;
            end 

            get_input:
            begin
                a <= input_a;
                b <= input_b;
                state <= unpack;
            end

            unpack:
            begin
                a_man <= {a[22:0], 3'b0};
                b_man <= {b[22:0], 3'b0};
                a_exp <= a[30:23] - 127;
                b_exp <= b[30:23] - 127;
                a_sign <= a[31];
                b_sign <= b[31];
                state <= special_cases;
            end

            special_cases:
            begin
                // If a is NaN or b is NaN, return NaN
                if ((a_exp == 128 && a_man != 0) || (b_exp == 128 && b_man != 0)) begin
                    // z = NaN
                    z[31] <= 1;
                    z[30:23] <= 255;
                    z[22:0] <= {1'b1, 22'b0};
                    state <= put_z;
                end
                // If a is inf, return inf
                else if (a_exp == 128) begin
                    // z = inf
                    z[31] <= a_sign;
                    z[30:23] <= 255;
                    z[22:0] <= 0;

                    // If a is inf and signs don't match, return NaN
                    if ((b_exp == 128) && (a_sign != b_sign)) begin
                        // z = NaN
                        z[31] <= 1;
                        z[30:23] <= 255;
                        z[22:0] <= {1'b1, 22'b0};
                    end

                    state <= put_z;
                end 
                // If b is inf, return inf
                else if (b_exp == 128) begin
                    // z = inf
                    z[31] <= a_sign;
                    z[30:23] <= 255;
                    z[22:0] <= 0;
                    state <= put_z;
                end
                // If a is zero and b is zero, return signed zero
                else if ((($signed(a_exp) == -127) && (a_man == 0)) && (($signed(b_exp) == -127) && (b_man == 0))) begin
                    z[31] <= a_sign & b_sign;
                    z[30:23] <= b_exp[7:0] + 127;
                    z[22:0] <= b_man[26:3];
                    state <= put_z;
                end
                // If a is zero, return b
                else if (($signed(a_exp) == -127) && (a_man == 0)) begin
                    z[31] <= b_sign;
                    z[30:23] <= b_exp[7:0] + 127;
                    z[22:0] <= b_man[26:3];
                    state <= put_z;
                end
                // If b is zero, return a
                else if (($signed(b_exp) == -127) && (b_man == 0)) begin
                    z[31] <= a_sign;
                    z[30:23] <= a_exp[7:0] + 127;
                    z[22:0] <= a_man[26:3];
                    state <= put_z;
                end
                else begin
                    // Denormalized Number a
                    if ($signed(a_exp) == -127) 
                        a_exp <= -126;
                    else 
                        a_man[26] <= 1;
                    // Denormalized Number b
                    if ($signed(b_exp) == -127)
                        b_exp <= -126;
                    else
                        b_man[26] <= 1;
                end

                state <= align;
            end 

            align:
            begin
                if ($signed(a_exp) > $signed(b_exp)) begin
                    b_exp <= b_exp + 1;
                    b_man <= b_man >> 1;
                    b_man[0] <= b_man[0] | b_man[1];
                end 
                else if ($signed(a_exp) < $signed(b_exp)) begin
                    a_exp <= a_exp + 1;
                    a_man <= a_man >> 1;
                    a_man[0] <= a_man[0] | a_man[1];
                end 
                else begin
                    state <= add_0;
                end
            end

            add_0:
            begin
                z_exp <= a_exp;
                if (a_sign == b_sign) begin
                    sum <= a_man + b_man;
                    z_sign <= a_sign;
                end 
                else begin
                    if (a_man >= b_man) begin
                        sum <= a_man - b_man;
                        z_sign <= a_sign;
                    end 
                    else begin
                        sum <= b_man - a_man;
                        z_sign <= b_sign;
                    end
                end
                state <= add_1;
            end

            add_1:
            begin
                if (sum[27]) begin
                    z_man <= sum[27:4];
                    guard <= sum[3];
                    round_bit <= sum[2];
                    sticky <= sum[1] | sum[0];
                    z_exp <= z_exp + 1;
                end 
                else begin
                    z_man <= sum[26:3];
                    guard <= sum[2];
                    round_bit <= sum[1];
                    sticky <= sum[0];
                end
                state <= normalise_1;
            end

            normalise_1:
            begin
                if (z_man[23] == 0 && $signed(z_exp) > -126) begin
                    z_exp <= z_exp - 1;
                    z_man <= z_man << 1;
                    z_man[0] <= guard;
                    guard <= round_bit;
                    round_bit <= 0;
                end 
                else begin
                    state <= normalise_2;
                end
            end

            normalise_2:
            begin
                if ($signed(z_exp) < -126) begin
                    z_exp <= z_exp + 1;
                    z_man <= z_man >> 1;
                    guard <= z_man[0];
                    round_bit <= guard;
                    sticky <= sticky | round_bit;
                end 
                else begin
                    state <= round;
                end
            end

            round:
            begin
                if (guard && (round_bit | sticky | z_man[0])) begin
                    z_man <= z_man + 1;
                    // z_man[0] <= 0;
                    if (z_man == 24'hffffff) begin
                        z_exp <= z_exp + 1;
                    end
                end
                state <= pack;
            end

            pack:
            begin
                z[22 : 0] <= z_man[22:0];
                z[30 : 23] <= z_exp[7:0] + 127;
                z[31] <= z_sign;
                if ($signed(z_exp) == -126 && z_man[23] == 0) begin
                    z[30 : 23] <= 0;
                end
                if ($signed(z_exp) == -126 && z_man[23:0] == 24'h0) begin
                    z[31] <= 1'b0; // FIX SIGN BUG: -a + a = +0.
                end
                //if overflow occurs, return inf
                if ($signed(z_exp) > 127) begin
                    z[22 : 0] <= 0;
                    z[30 : 23] <= 255;
                    z[31] <= z_sign;
                end
                state <= put_z;
            end

            put_z:
            begin
                output_z <= z;
                DONE <= `TRUE;
                state <= ready;            
            end

        endcase
    end
    
endmodule

module float32_mul (
    input CLK, RST, EN,
    input [31:0] input_a, input_b,
    output reg [31:0] output_z,
    output reg DONE
    );

    reg [3:0] state;
    parameter   ready         = 4'd0,
                get_input     = 4'd1,
                unpack        = 4'd2,
                special_cases = 4'd3,
                normalise_a   = 4'd4,
                normalise_b   = 4'd5,
                multiply_0    = 4'd6,
                multiply_1    = 4'd7,
                normalise_1   = 4'd8,
                normalise_2   = 4'd9,
                round         = 4'd10,
                pack          = 4'd11,
                put_z         = 4'd12;

    reg       [31:0] a, b, z;
    reg       [23:0] a_man, b_man, z_man;
    reg       [9:0] a_exp, b_exp, z_exp;
    reg       a_sign, b_sign, z_sign;
    reg       guard, round_bit, sticky;
    reg       [47:0] product;

    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            state <= ready;
            // Write initialization code here
            output_z <= 0;
            DONE <= `FALSE;

            a <= 0; b <= 0; z <= 0;
            a_man <= 0; b_man <= 0; z_man <= 0;
            a_exp <= 0; b_exp <= 0; z_exp <= 0;
            a_sign <= 0; b_sign <= 0; z_sign <= 0;
            guard <= 0; round_bit <= 0; sticky <= 0;
            product <= 0;
        end

        case (state)
            ready:
            begin
                if (EN) state <= get_input;
                else    state <= ready;
                DONE <= `FALSE;

                a <= 0; b <= 0; z <= 0;
                a_man <= 0; b_man <= 0; z_man <= 0;
                a_exp <= 0; b_exp <= 0; z_exp <= 0;
                a_sign <= 0; b_sign <= 0; z_sign <= 0;
                guard <= 0; round_bit <= 0; sticky <= 0;
                product <= 0;
            end 

            get_input:
            begin
                a <= input_a;
                b <= input_b;
                state <= unpack;
            end

            unpack:
            begin
                a_man <= a[22:0];
                b_man <= b[22:0];
                a_exp <= a[30:23] - 127;
                b_exp <= b[30:23] - 127;
                a_sign <= a[31];
                b_sign <= b[31];
                state <= special_cases;
            end

            special_cases:
            begin
                // if a is NaN or b is Nan return Nan
                if ((a_exp == 128 && a_man != 0) || (b_exp == 128 && b_man != 0)) begin
                    z[31] <= 1;
                    z[30:23] <= 255;
                    z[22] <= 1;
                    z[21:0] <= 0;
                    state <= put_z;
                end
                // if a is inf return inf
                else if (a_exp == 128) begin
                    z[31] <= a_sign ^ b_sign;
                    z[30:23] <= 255;
                    z[22:0] <= 0;
                    // if b is zero return NaN
                    if (($signed(b_exp) == -127) && (b_man == 0)) begin
                        z[31] <= 1;
                        z[30:23] <= 255;
                        z[22] <= 1;
                        z[21:0] <= 0;
                    end
                    state <= put_z;
                end
                // if b is inf return inf
                else if (b_exp == 128) begin
                    z[31] <= a_sign ^ b_sign;
                    z[30:23] <= 255;
                    z[22:0] <= 0;
                    // if a is zero return NaN
                    if (($signed(a_exp) == -127) && (a_man == 0)) begin
                        z[31] <= 1;
                        z[30:23] <= 255;
                        z[22] <= 1;
                        z[21:0] <= 0;
                    end
                    state <= put_z;
                end
                // if a is zero return zero
                else if (($signed(a_exp) == -127) && (a_man == 0)) begin
                    z[31] <= a_sign ^ b_sign;
                    z[30:23] <= 0;
                    z[22:0] <= 0;
                    state <= put_z;
                end
                // if b is zero return zero
                else if (($signed(b_exp) == -127) && (b_man == 0)) begin
                    z[31] <= a_sign ^ b_sign;
                    z[30:23] <= 0;
                    z[22:0] <= 0;
                    state <= put_z;
                end 
                // Denormalised Number
                else begin
                    if ($signed(a_exp) == -127) a_exp <= -126;
                    else                        a_man[23] <= 1;

                    if ($signed(b_exp) == -127) b_exp <= -126;
                    else                        b_man[23] <= 1;
                    state <= normalise_a;
                end
            end

            normalise_a:
            begin
                if(a_man[23]) begin
                    state <= normalise_b;
                end
                else begin
                    a_man <= (a_man << 1);
                    a_exp <= a_exp - 1;
                end
            end

            normalise_b:
            begin
                if(b_man[23]) begin
                    state <= multiply_0;
                end
                else begin
                    b_man <= (b_man << 1);
                    b_exp <= b_exp - 1;
                end
            end

            multiply_0:
            begin
                z_sign <= a_sign ^ b_sign;
                z_exp <= a_exp + b_exp + 1;
                product <= a_man * b_man;
                state <= multiply_1; 
            end

            multiply_1:
            begin
                z_man <= product[47:24];
                guard <= product[23];
                round_bit <= product[22];
                sticky <= (product[21:0] != 0);
                state <= normalise_1;
            end

            normalise_1:
            begin
                if (z_man[23] == 0) begin
                    z_exp <= z_exp - 1;
                    z_man <= z_man << 1;
                    z_man[0] <= guard;
                    guard <= round_bit;
                    round_bit <= 0; 
                end    
                else begin
                    state <= normalise_2;
                end
            end

            normalise_2:
            begin
                if ($signed(z_exp) < -126) begin
                    z_exp <= z_exp + 1;
                    z_man <= z_man >> 1;
                    guard <= z_man[0];
                    round_bit <= guard;
                    sticky <= sticky | round_bit;
                end
                else begin
                    state <= round;
                end
            end

            round:
            begin
                if (guard && (round_bit | sticky | z_man[0])) begin
                    z_man <= z_man + 1;
                    // z_man[0] <= 0;

                    if (z_man == 24'hffffff) 
                        z_exp <= z_exp + 1;
                end
                state <= pack;
            end

            pack:
            begin
                z[22 : 0] <= z_man[22:0];
                z[30 : 23] <= z_exp[7:0] + 127;
                z[31] <= z_sign;
                if ($signed(z_exp) == -126 && z_man[23] == 0) 
                    z[30 : 23] <= 0;
                
                // if overflow occurs return inf
                if ($signed(z_exp) > 127) begin
                    z[22:0] <= 0;
                    z[30:23] <= 255;
                    z[31] <= z_sign; 
                end
                state <= put_z;
            end

            put_z:
            begin
                output_z <= z;
                DONE <= `TRUE;
                state <= ready; 
            end

        endcase
    end
    
endmodule


module SegmentOutput (
    input CLK, RST,
    input [3:0] iDEC7, iDEC6, iDEC5, iDEC4, iDEC3, iDEC2, iDEC1, iDEC0,
    output [7:0] oS_COM,
    output [7:0] oS_ENS
    );
    wire [7:0] wSEG [7:0];
    BCD_to_7segment iSEG0(.Din(iDEC0), .Sout(wSEG[0]));
    BCD_to_7segment iSEG1(.Din(iDEC1), .Sout(wSEG[1]));
    BCD_to_7segment iSEG2(.Din(iDEC2), .Sout(wSEG[2]));
    BCD_to_7segment iSEG3(.Din(iDEC3), .Sout(wSEG[3]));
    BCD_to_7segment iSEG4(.Din(iDEC4), .Sout(wSEG[4]));
    BCD_to_7segment iSEG5(.Din(iDEC5), .Sout(wSEG[5]));
    BCD_to_7segment iSEG6(.Din(iDEC6), .Sout(wSEG[6]));
    BCD_to_7segment iSEG7(.Din(iDEC7), .Sout(wSEG[7]));
    SevenSeg_CTRL SEG_CTRL(.iCLK(CLK), .nRST(RST), 
                            .iSEG7(wSEG[7]), .iSEG6(wSEG[6]), .iSEG5(wSEG[5]), .iSEG4(wSEG[4]), 
                            .iSEG3(wSEG[3]), .iSEG2(wSEG[2]), .iSEG1(wSEG[1]), .iSEG0(wSEG[0]),
                            .oS_COM(oS_COM), .oS_ENS(oS_ENS));

endmodule

module SevenSeg_CTRL(
	iCLK,
	nRST,
	iSEG7,
	iSEG6,
	iSEG5,
	iSEG4,
	iSEG3,
	iSEG2,
	iSEG1,
	iSEG0,
	oS_COM,
	oS_ENS
    );
    // I/O definition------------------------------------------	
    input iCLK, nRST;
    input [7:0] iSEG7, iSEG6, iSEG5, iSEG4, iSEG3, iSEG2, iSEG1, iSEG0;
    output [7:0] oS_COM;
    output [7:0] oS_ENS; /* a,b,c,d,e,f,g,dp */
    reg [7:0] oS_COM;
    reg [7:0] oS_ENS;
    integer CNT_SCAN = 0; 

    /*
    [a]
    [f]   [b]
    [g]
    [e]   [c]
    [d]   [dp]
    */

    always @(posedge iCLK)
    begin
        if (!nRST)
        begin
            oS_COM <= 8'b00000000;
            oS_ENS <= 0;
            CNT_SCAN = 0;
        end
        else
        begin
            if (CNT_SCAN >= 8)
            CNT_SCAN = 0;
            else
            CNT_SCAN = CNT_SCAN + 1;
                    
            case (CNT_SCAN)
            0 : 
                begin
                    oS_COM <= 8'b11111110;
                    oS_ENS <= iSEG0;
                end
            1 : 
                begin
                    oS_COM <= 8'b11111101;
                    oS_ENS <= iSEG1;
                end
            2 : 
                begin
                    oS_COM <= 8'b11111011;
                    oS_ENS <= iSEG2;
                end
            3 : 
                begin
                    oS_COM <= 8'b11110111;
                    oS_ENS <= iSEG3;
                end
            4 : 
                begin
                    oS_COM <= 8'b11101111;
                    oS_ENS <= iSEG4;
                end
            5 : 
                begin
                    oS_COM <= 8'b11011111;
                    oS_ENS <= iSEG5;
                end
            6 : 
                begin
                    oS_COM <= 8'b10111111;
                    oS_ENS <= iSEG6;
                end
            7 : 
                begin
                    oS_COM <= 8'b01111111;
                    oS_ENS <= iSEG7;
                end			 
            default : 
                begin
                oS_COM <= 8'b11111111;
                    oS_ENS <= iSEG7;
                end
            endcase
        end
    end

endmodule


module BCD_to_7segment(
	input [3:0] Din,
	output reg [7:0] Sout //A, B, C, D, E, F, G, DP
    );

    /*
    [a]
    [f]   [b]
    [g]
    [e]   [c]
    [d]   [dp]
    */

    always @(Din)
    begin
        case(Din)
            4'b0000 : Sout <= 8'b11111100; //0
            4'b0001 : Sout <= 8'b01100000; //1
            4'b0010 : Sout <= 8'b11011010; //2
            4'b0011 : Sout <= 8'b11110010; //3
            4'b0100 : Sout <= 8'b01100110; //4
            4'b0101 : Sout <= 8'b10110110; //5
            4'b0110 : Sout <= 8'b10111110; //6
            4'b0111 : Sout <= 8'b11100100; //7
            4'b1000 : Sout <= 8'b11111110; //8
            4'b1001 : Sout <= 8'b11110110; //9
            4'b1010 : Sout <= 8'b00000001; //*
            default : Sout <= 8'b11111100; //NULL
        endcase 
    end

endmodule

