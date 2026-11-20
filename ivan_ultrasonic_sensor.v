
//Still needs to be incorporated in the main module
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

endmodule
