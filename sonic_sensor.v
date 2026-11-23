`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UTSA
// Engineer: Morton
// Create Date: 11/08/2024 02:33:37 PM
//////////////////////////////////////////////////////////////////////////////////

module BBa (
    input  wire        clk100,
    input  wire [15:0] sw,
    output wire [7:0]  seg,
    output wire [7:0]  disp,
    output wire        PWM,
    output wire        Trig,
    input  wire        Echo,
    output wire        red1,
    output wire        TestA2
);

    localparam [19:0] LEVEL = 20'd145000;
    localparam [31:0] TARGET = 32'h0002C200;

    wire [31:0] distance_count;
    wire        new_sample;
    wire        sample_valid;

    reg [19:0] auto_command = LEVEL;
    reg [19:0] manual_command;

    wire [19:0] selected_command;

    // Ultrasonic sensor
    ultrasonic_reader SENSOR (
        .clk100(clk100),
        .Echo(Echo),
        .Trig(Trig),
        .distance_count(distance_count),
        .new_sample(new_sample),
        .sample_valid(sample_valid)
    );

    // Manual servo commands
    always @(*) begin
        case (sw[1:0])
            2'b00: manual_command = LEVEL;
            2'b01: manual_command = 20'd135000;
            2'b10: manual_command = 20'd151000;
            2'b11: manual_command = LEVEL;
            default: manual_command = LEVEL;
        endcase
    end

    // Automatic zone controller with damping
    reg [31:0] error_magnitude;
    reg        ball_far;
    reg [19:0] correction;
    reg [19:0] next_auto_command;

    reg [31:0] previous_distance = 32'd0;
    reg        have_previous = 1'b0;

    reg [31:0] movement;
    reg        moving_toward_center;

    always @(*) begin

        ball_far = (distance_count > TARGET);

        if (ball_far)
            error_magnitude = distance_count - TARGET;
        else
            error_magnitude = TARGET - distance_count;

        if (distance_count >= previous_distance)
            movement = distance_count - previous_distance;
        else
            movement = previous_distance - distance_count;

        moving_toward_center = have_previous && (movement > 32'h00000400) && ((ball_far && distance_count < previous_distance) || (!ball_far && distance_count > previous_distance));

        // Position-based correction
        if (error_magnitude < 32'h00000600)
            correction = 20'd0;
        else if (error_magnitude < 32'h00004000)
            correction = ball_far ? 20'd10000 : 20'd2500;
        else if (error_magnitude < 32'h0000A000)
            correction = ball_far ? 20'd11000 : 20'd5000;
        else
            correction = ball_far ? 20'd16000 : 20'd10000;

        //velocity-based damping
        if (moving_toward_center)
            correction = correction >> 1;

        if (ball_far ^ sw[14])
            next_auto_command = LEVEL + correction;
        else
            next_auto_command = LEVEL - correction;

    end

    // Update automatic servo command
    always @(posedge clk100) begin
        if (new_sample) begin

            if (sample_valid && distance_count >= 32'h00002000 && distance_count <= 32'h00058000) begin

                auto_command <= next_auto_command;

                previous_distance <= distance_count;
                have_previous <= 1'b1;

            end
            else begin

                auto_command <= LEVEL;
                have_previous <= 1'b0;

            end
        end
    end

    // Select manual or automatic mode
    assign selected_command = sw[15] ? auto_command : manual_command;

    // Servo PWM generator
    bb_servo_pwm SERVO ( .clk100(clk100), .command(selected_command), .PWM(PWM) );

    // Seven-segment HEX display
    bb_hex_display DISPLAY ( .clk100(clk100), .value(distance_count), .seg(seg), .disp(disp) );

    assign red1 = sw[15] && sample_valid && (error_magnitude < 32'h00001000);

    assign TestA2 = PWM;

endmodule

// ULTRASONIC SENSOR READER

module ultrasonic_reader (
    input  wire        clk100,
    input  wire        Echo,
    output wire        Trig,
    output reg [31:0]  distance_count = 32'd0,
    output reg         new_sample = 1'b0,
    output reg         sample_valid = 1'b0
);

    localparam [2:0] TRIGGER   = 3'd0;
    localparam [2:0] WAIT_RISE = 3'd1;
    localparam [2:0] MEASURE   = 3'd2;
    localparam [2:0] COOLDOWN  = 3'd3;

    localparam [22:0] TRIG_TICKS = 23'd1000;
    localparam [22:0] TIMEOUT    = 23'd3000000;
    localparam [22:0] CYCLE      = 23'd6000000;

    reg [2:0] state = TRIGGER; // State machine for ultrasonic Trigger/Echo measurement
    reg [22:0] timer = 23'd0; // Counts 100 MHz clock cycles
    reg [31:0] echo_count = 32'd0;

    reg echo_meta = 1'b0;
    reg echo_sync = 1'b0;

    always @(posedge clk100) begin
        echo_meta <= Echo; // Synchronize the asynchronous Echo input
        echo_sync <= echo_meta;
    end

    assign Trig = (state == TRIGGER);

    always @(posedge clk100) begin

        new_sample <= 1'b0;

        case (state)

            TRIGGER: begin
                if (timer == TRIG_TICKS - 1) begin
                    timer <= 23'd0;
                    state <= WAIT_RISE;
                end
                else
                    timer <= timer + 1'b1;
            end

            WAIT_RISE: begin
                if (echo_sync) begin
                    timer <= 23'd0;
                    echo_count <= 32'd0;
                    state <= MEASURE;
                end
                else if (timer == TIMEOUT - 1) begin
                    timer <= 23'd0;
                    sample_valid <= 1'b0;
                    new_sample <= 1'b1;
                    state <= COOLDOWN;
                end
                else
                    timer <= timer + 1'b1;
            end

            MEASURE: begin
                if (!echo_sync) begin
                    distance_count <= echo_count;
                    sample_valid <= 1'b1;
                    new_sample <= 1'b1;
                    timer <= 23'd0;
                    state <= COOLDOWN;
                end
                else if (timer == TIMEOUT - 1) begin
                    timer <= 23'd0;
                    sample_valid <= 1'b0;
                    new_sample <= 1'b1;
                    state <= COOLDOWN;
                end
                else begin
                    echo_count <= echo_count + 1'b1;
                    timer <= timer + 1'b1;
                end
            end

            COOLDOWN: begin
                if (timer == CYCLE - 1) begin
                    timer <= 23'd0;
                    state <= TRIGGER;
                end
                else
                    timer <= timer + 1'b1;
            end

            default: begin
                state <= TRIGGER;
                timer <= 23'd0;
            end

        endcase
    end

endmodule

// SERVO PWM GENERATOR

module bb_servo_pwm (
    input  wire        clk100,
    input  wire [19:0] command,
    output wire        PWM
);

    localparam [19:0] PERIOD  = 20'd600000;
    localparam [19:0] MIN_PWM = 20'd100000;
    localparam [19:0] MAX_PWM = 20'd200000;

    reg [19:0] counter = 20'd0;

    wire [19:0] safe_command;

    assign safe_command = (command < MIN_PWM) ? MIN_PWM : (command > MAX_PWM) ? MAX_PWM : command;

    always @(posedge clk100) begin
        if (counter == PERIOD - 1)
            counter <= 20'd0;
        else
            counter <= counter + 1'b1;
    end

    assign PWM = (counter < safe_command);

endmodule

// EIGHT-DIGIT HEX DISPLAY

module bb_hex_display (
    input  wire        clk100,
    input  wire [31:0] value,
    output reg  [7:0]  seg = 8'hFF,
    output reg  [7:0]  disp = 8'hFF
);

    reg [16:0] refresh = 17'd0;
    reg [2:0] digit;
    reg [3:0] hex_value;

    always @(posedge clk100)
        refresh <= refresh + 1'b1;

    always @(*) begin

        digit = refresh[16:14];

        case (digit)
            3'd0: hex_value = value[3:0];
            3'd1: hex_value = value[7:4];
            3'd2: hex_value = value[11:8];
            3'd3: hex_value = value[15:12];
            3'd4: hex_value = value[19:16];
            3'd5: hex_value = value[23:20];
            3'd6: hex_value = value[27:24];
            3'd7: hex_value = value[31:28];
            default: hex_value = 4'h0;
        endcase

        disp = ~(8'b00000001 << digit);

        case (hex_value)
            4'h0: seg = 8'b11000000;
            4'h1: seg = 8'b11111001;
            4'h2: seg = 8'b10100100;
            4'h3: seg = 8'b10110000;
            4'h4: seg = 8'b10011001;
            4'h5: seg = 8'b10010010;
            4'h6: seg = 8'b10000010;
            4'h7: seg = 8'b11111000;
            4'h8: seg = 8'b10000000;
            4'h9: seg = 8'b10010000;
            4'hA: seg = 8'b10001000;
            4'hB: seg = 8'b10000011;
            4'hC: seg = 8'b11000110;
            4'hD: seg = 8'b10100001;
            4'hE: seg = 8'b10000110;
            4'hF: seg = 8'b10001110;
            default: seg = 8'hFF;
        endcase

    end

endmodule