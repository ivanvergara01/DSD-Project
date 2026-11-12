`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2026 08:40:45 PM
// Design Name: 
// Module Name: display_sensor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module BBa(clk100, sw, seg, disp, PWM, Trig, Echo, red1, TestA2);
    input clk100;
    input [15:0] sw;
    output [7:0] seg;
    output [7:0] disp;
    output PWM;
    output Trig;
    input Echo;
    output red1;
    output TestA2;
    reg [31:0] count;
    reg [3:0] NextState;
    wire [3:0] State;
    reg RTrig;
    reg [31:0] RPeriod;
    wire [31:0] Period;
    reg [31:0] RIBuff;

    assign State = NextState;
    assign Trig = RTrig;

    initial begin
        NextState <= 4'h0;
    end
    assign TestA2 = count[19];
    PWM_Gen IN105 (clk100, {sw, 4'b0000}, PWM); 
    always @(posedge clk100) begin
        count <= count + 1;
        case (State)
            4'h0: begin
                RTrig = 1'b0; 
                RPeriod = 1'b0;
                count <= 32'h00000000; 
                NextState = 4'h1; 
            end
            4'h1: begin
                if (count < 32'd1_000) begin
                    RTrig <= 1'b1;
                    RPeriod <= 32'h00000000;
                end
                else if ((count >= 32'd1_000) && (count < 32'd6_000_000)) begin 
                    RTrig <= 1'b0;
                    if (Echo == 1'b1) RPeriod <= RPeriod + 32'd1;
                end
                else begin
                    NextState <= 4'h2;
                end
            end
            4'h2: begin
                RIBuff <= RPeriod;
                NextState <= 4'h0;
            end
        endcase
    end
    SSEG IN106 (seg, disp, clk100, RIBuff[15:0], sw);
endmodule
