//======================================================
// DUT
//======================================================
 
module vending_machine (
    input  logic clk,
    input  logic reset,
    input  logic coin_5,
    input  logic coin_10,
    input  logic coin_20,
    output logic dispense,
    output logic change_5
);
    typedef enum logic [1:0] {
        IDLE_0   = 2'b00,
        MONEY_5  = 2'b01,
        MONEY_10 = 2'b10
    } state_t;
    state_t state, next_state;
    //==================================================
    // STATE REGISTER
    //==================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE_0;
        else
            state <= next_state;
    end
    //==================================================
    // NEXT STATE LOGIC
    //==================================================
    always_comb begin
        next_state = state;
        case (state)
            IDLE_0: begin
                if (coin_5)
                    next_state = MONEY_5;
                else if (coin_10)
                    next_state = MONEY_10;
                else if (coin_20)
                    next_state = IDLE_0;
            end
            MONEY_5: begin
                if (coin_5)
                    next_state = MONEY_10;
                else if (coin_10)
                    next_state = IDLE_0;
                else
                    next_state = MONEY_5;
            end
            MONEY_10: begin
                if (coin_5)
                    next_state = IDLE_0;
                else if (coin_10)
                    next_state = IDLE_0;
                else
                    next_state = MONEY_10;
            end
            default:
                next_state = IDLE_0;
        endcase
    end
    //==================================================
    // OUTPUT LOGIC
    //==================================================
    always_comb begin
        dispense = 1'b0;
        change_5 = 1'b0;
        case (state)
            IDLE_0: begin
                if (coin_20) begin
                    dispense = 1'b1;
                    change_5 = 1'b1;
                end
            end
            MONEY_5: begin
                if (coin_10) begin
                    dispense = 1'b1;
                end
            end
            MONEY_10: begin
                if (coin_5) begin
                    dispense = 1'b1;
                end
                else if (coin_10) begin
                    dispense = 1'b1;
                    change_5 = 1'b1;
                end
            end
            default: begin
                dispense = 1'b0;
                change_5 = 1'b0;
            end
        endcase
    end
endmodule