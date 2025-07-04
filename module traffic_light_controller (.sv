module traffic_light_controller (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         sensor,       // Sensor to detect cars on minor road
    output logic [2:0]  main_lights,  // [2]=Red, [1]=Yellow, [0]=Green
    output logic [2:0]  minor_lights  // [2]=Red, [1]=Yellow, [0]=Green
);

    // Traffic light encoding
    localparam logic [2:0] RED    = 3'b100;
    localparam logic [2:0] YELLOW = 3'b010;
    localparam logic [2:0] GREEN  = 3'b001;

    // FSM States using SystemVerilog enum
    typedef enum logic [1:0] {
        MAIN_GREEN   = 2'b00,  // Main road green, minor road red
        MAIN_YELLOW  = 2'b01,  // Main road yellow, minor road red
        MINOR_GREEN  = 2'b10,  // Main road red, minor road green
        MINOR_YELLOW = 2'b11   // Main road red, minor road yellow
    } state_t;

    state_t current_state, next_state;

    // Timing parameters (in clock cycles)
    localparam int MAIN_GREEN_TIME  = 50;  // 50 cycles for main green
    localparam int YELLOW_TIME      = 10;  // 10 cycles for yellow
    localparam int MINOR_GREEN_TIME = 30;  // 30 cycles for minor green

    // Timer counter
    logic [7:0] timer;
    logic       timer_expired;

   //========================================================================
   // State Register - Sequential Logic
   //========================================================================
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            current_state <= MAIN_GREEN;
            timer <= 8'b0;
        end else begin
            current_state <= next_state;
            // Reset timer on state change, otherwise increment
            if (current_state != next_state)
                timer <= 8'b0;
            else
                timer <= timer + 1'b1;
        end
    end

   //========================================================================
   // Timer Logic - Combinational Logic
   //========================================================================
    always_comb begin
        case (current_state)
            MAIN_GREEN:   timer_expired = (timer >= MAIN_GREEN_TIME - 1);
            MAIN_YELLOW:  timer_expired = (timer >= YELLOW_TIME - 1);
            MINOR_GREEN:  timer_expired = (timer >= MINOR_GREEN_TIME - 1);
            MINOR_YELLOW: timer_expired = (timer >= YELLOW_TIME - 1);
            default:      timer_expired = 1'b0; // Safety default
        endcase
    end

   //========================================================================
   // Next State Logic - Combinational Logic
   //========================================================================
    always_comb begin
        // Default to staying in the current state unless a condition for transition is met
        next_state = current_state;

        case (current_state)
            MAIN_GREEN:
                // Transition to MAIN_YELLOW if timer expires AND sensor detects a car
                if (timer_expired && sensor)
                    next_state = MAIN_YELLOW;
                // If timer expires but no sensor, potentially stay in MAIN_GREEN
                // (or implement a longer main green without minor road traffic)
                // For simplicity here, it will just remain in MAIN_GREEN if no sensor.
                // You might want a minimum green time for main road even without sensor.

            MAIN_YELLOW:
                // Transition to MINOR_GREEN after yellow time
                if (timer_expired)
                    next_state = MINOR_GREEN;

            MINOR_GREEN:
                // Transition to MINOR_YELLOW after minor green time
                if (timer_expired)
                    next_state = MINOR_YELLOW;

            MINOR_YELLOW:
                // Transition back to MAIN_GREEN after minor yellow time
                if (timer_expired)
                    next_state = MAIN_GREEN;

            default:
                next_state = MAIN_GREEN; // Reset to a known state if somehow in an invalid state
        endcase
    end

   //========================================================================
   // Output Logic - Combinational Logic
   //========================================================================
    always_comb begin
        // Default all lights to red for safety
        main_lights = RED;
        minor_lights = RED;

        case (current_state)
            MAIN_GREEN: begin
                main_lights = GREEN;
                minor_lights = RED;
            end
            MAIN_YELLOW: begin
                main_lights = YELLOW;
                minor_lights = RED;
            end
            MINOR_GREEN: begin
                main_lights = RED;
                minor_lights = GREEN;
            end
            MINOR_YELLOW: begin
                main_lights = RED;
                minor_lights = YELLOW;
            end
            default: begin
                // In case of an unexpected state, keep both lights red for safety
                main_lights = RED;
                minor_lights = RED;
            end
        endcase
    end

endmodule