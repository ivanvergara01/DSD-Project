`timescale 1ns / 1ps

module BBa(clk100,sw,seg,disp,PWM,Trig,Echo,red1,TestA2, oled_sda, oled_scl);
    input clk100;
    input [15:0] sw;
    output [7:0] seg;
    output [7:0] disp;
    output PWM;
    output Trig;
    input Echo;
    output red1;
    output TestA2;
    inout wire oled_sda;
    inout wire oled_scl;
    

   reg [31:0] count = 0;
   wire [31:0] Distance;
   
    ultrasonic_sensor IN107(
    .clk(clk100),
    .Echo(Ech0),
    .Trig(Trig),
    .Distance(Distance)
    );

    
    assign TestA2 = count[19];
    
    PWM_Gen IN105 (clk100,{sw,4'b0000}, PWM); //Replace the concatination with the PID output
    
    always @(posedge clk100) begin //This holds the state machine for the project tick "posedge count[19]"
    count <= count+1;
    end
    
    SSEG IN106 (seg,disp,clk100,Distance,sw);
    
endmodule
// ***********************************************************
module PWM_Gen(clk100, Input, PWM_Pulse);
    input clk100;
    input [63:0] Input;
    output reg PWM_Pulse;
    reg [63:0] Count;
    // reg [63:0] RInput;
    wire [63:0] RInput;
    initial begin
    Count = 0;
    PWM_Pulse = 0;
    end
    always@(posedge clk100) begin
    Count <= Count + 64'd1;
    if(Count == 64'd600_000) Count <= 64'd0000000; // ***Changed to 6ms period
    end
    //Limits PWM output to range of 1ms to 2ms = useful range
    assign RInput = (Input < 64'd100_000)? 64'd100_000:((Input > 64'd200_000)? 64'd200_000:Input);
    always@(*) begin
    if(RInput > Count) PWM_Pulse = 1;
    else PWM_Pulse = 0;
    end
endmodule
// ***************************************************************
module SSEG (seg,disp,clk100,BCD,PWM);
    input wire clk100;
    input wire [31:0] BCD;
    input wire [15:0] PWM;
    output reg [7:0]seg;
    output reg [7:0] disp;
    reg [3:0] Location = 0;
    reg[3:0] Digit;
    initial begin
    seg = 8'b00000000;
    disp = 8'b00000000;
    Location = 0;
    Digit = 0;
    end
    wire Clk_Multi;
    CLK100MHZ_divider IN432476(clk100, Clk_Multi);
    always@(*) begin
    if(Digit == 4'b0000) seg[6:0] = 7'b1000000; // Make 0 with LEDs
    if(Digit == 4'b0001) seg[6:0] = 7'b1001111; // Make 1 with LEDs
    if(Digit == 4'b0010) seg[6:0] = 7'b0100100; // Make 2 with LEDs
    if(Digit == 4'b0011) seg[6:0] = 7'b0110000; // Make 3 with LEDs
    if(Digit == 4'b0100) seg[6:0] = 7'b0011001; // Make 4 with LEDs
    if(Digit == 4'b0101) seg[6:0] = 7'b0010010; // Make 5 with LEDs
    if(Digit == 4'b0110) seg[6:0] = 7'b0000010; // Make 6 with LEDs
    if(Digit == 4'b0111) seg[6:0] = 7'b1111000; // Make 7 with LEDs
    if(Digit == 4'b1000) seg[6:0] = 7'b0000000; // Make 8 with LEDs
    if(Digit == 4'b1001) seg[6:0] = 7'b0011000; // Make 9 with LEDs
    if(Digit == 4'b1010) seg[6:0] = 7'b0001000; // Make A with LEDs
    if(Digit == 4'b1011) seg[6:0] = 7'b0000011; // Make b with LEDs
    if(Digit == 4'b1100) seg[6:0] = 7'b1000110; // Make C with LEDs
    if(Digit == 4'b1101) seg[6:0] = 7'b0100001; // Make d with LEDs
    if(Digit == 4'b1110) seg[6:0] = 7'b0000110; // Make E with LEDs
    if(Digit == 4'b1111) seg[6:0] = 7'b0001110; // Make F with LEDs
    end
    always@(posedge Clk_Multi) begin
    Location <= Location + 1;
    case(Location)
    0: begin
    disp <= 8'b11111110;
    {seg[7],Digit} <= {1'b1,BCD[7:4]};
    end
    1: begin
    disp <= 8'b11111101;
    {seg[7],Digit} <= {1'b1,BCD[11:8]};
    end
    2: begin
    disp <= 8'b11111011;
    {seg[7],Digit} <= {1'b1,BCD[15:12]};
    end
    3: begin
    disp <= 8'b11110111;
    {seg[7],Digit} <= {1'b1,BCD[19:16]};
    end
    4: begin
    disp <= 8'b11101111;
    {seg[7],Digit} <= {1'b1,PWM[03:00]};
    end
    5: begin
    disp <= 8'b11011111;
    {seg[7],Digit} <= {1'b1,PWM[07:04]};
    end
    6: begin
    disp <= 8'b10111111;
    {seg[7],Digit} <= {1'b1,PWM[11:08]};
    end
    7: begin
    disp <= 8'b01111111;
    {seg[7],Digit} <= {1'b1,PWM[15:12]};
    Location <= 0;
    end
    endcase
    end
endmodule
// ************************************************************************
module CLK100MHZ_divider(clk100, New_Clock);//New_Clock = 100M/10,000 = 10KHz
    input wire clk100; // Input clock signal
    output reg New_Clock; // Divided clock output
    reg [31:0] count = 32'b00000000; // [31:0] is large enough to hold any value
    initial begin
    New_Clock = 0;
    count = 0;
    end
    always @(posedge clk100) begin
    count <= count + 1; // Increment count
    if (count == 31'd10000) begin
    New_Clock <= ~New_Clock; // Toggle New Clock
    count <= 31'b0; // Reset count
    end
    end
endmodule
// ***********************************************************
//Added modules


module ultrasonic_sensor(clk, Echo, Trig, Distance);

    input wire clk;
    input wire Echo;
    output reg Trig;
    output reg [31:0] Distance;

    reg [31:0] counter = 0;
    reg [31:0] echo_time = 0;

    // Echo synchronization
    reg echo_meta = 0;
    reg echo_sync = 0;
    reg echo_previous = 0;

    // Trigger counter
    reg [31:0] trigger_counter = 0;

    // State and timeout counters
    reg [2:0] state = 0;
    reg [31:0] timeout_counter = 0;

    localparam IDLE     = 3'd0,
               TRIGGER  = 3'd1,
               WAIT_ECHO = 3'd2,
               MEASURE  = 3'd3,
               COMPLETE = 3'd4;

    initial begin
        Trig = 0;
        Distance = 0;
        counter = 0;
        echo_time = 0;
        timeout_counter = 0;
        trigger_counter = 0;
    end

    always @(posedge clk) begin

        // Synchronize Echo to the FPGA clock
        echo_meta <= Echo;
        echo_sync <= echo_meta;
        echo_previous <= echo_sync;

        case (state)

            IDLE: begin
                Trig <= 0;
                trigger_counter <= 0;
                timeout_counter <= 0;
                counter <= 0;
                state <= TRIGGER;
            end

            TRIGGER: begin
                if (trigger_counter < 1000) begin
                    Trig <= 1;
                    trigger_counter <= trigger_counter + 1;
                end
                else begin
                    Trig <= 0;
                    timeout_counter <= 0;
                    state <= WAIT_ECHO;
                end
            end

            WAIT_ECHO: begin
                if (echo_sync == 1'b1) begin
                    counter <= 0;
                    timeout_counter <= 0;
                    state <= MEASURE;
                end
                else if (timeout_counter >= 6_000_000) begin
                    Distance <= 0;
                    state <= COMPLETE;
                end
                else begin
                    timeout_counter <= timeout_counter + 1;
                end
            end

            MEASURE: begin
                // Echo has changed from HIGH to LOW
                if (echo_previous == 1'b1 &&
                    echo_sync == 1'b0) begin

                    echo_time <= counter;
                    Distance <= (counter + 2900) / 5800;
                    state <= COMPLETE;

                end

                // Measurement timeout
                else if (timeout_counter >= 6_000_000) begin
                    Distance <= 0;
                    state <= COMPLETE;
                end

                else begin
                    if (echo_sync == 1'b1)
                        counter <= counter + 1;

                    timeout_counter <= timeout_counter + 1;
                end
            end

            COMPLETE: begin
                Trig <= 0;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
                Trig <= 0;
            end

        endcase
    end
