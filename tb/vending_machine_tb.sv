`timescale 1ns/1ps

//======================================================
// INTERFACE
//======================================================
 
interface vending_if(input logic clk);
 
    logic reset;
 
    logic coin_5;
    logic coin_10;
    logic coin_20;
 
    logic dispense;
    logic change_5;
 
endinterface
 
 
 
//======================================================
// TRANSACTION
//======================================================
 
class transaction;
 
    rand bit coin_5;
    rand bit coin_10;
    rand bit coin_20;
 
    // Allow only zero or one coin at a time
    constraint valid_coin {
        coin_5 + coin_10 + coin_20 <= 1;
    }
 
    function void display(string name);
 
        $display(
            "[%s] coin_5=%0d coin_10=%0d coin_20=%0d",
            name,
            coin_5,
            coin_10,
            coin_20
        );
 
    endfunction
 
endclass
 
 
 
//======================================================
// GENERATOR
//======================================================
 
class generator;
 
    transaction tr;
 
    mailbox #(transaction) gen2drv;
 
    function new(mailbox #(transaction) gen2drv);
 
        this.gen2drv = gen2drv;
 
    endfunction
 
 
    task run();
 
        repeat (100) begin
 
            tr = new();
 
            assert(tr.randomize())
            else $fatal("Randomization failed");
 
            tr.display("GEN");
 
            gen2drv.put(tr);
 
        end
 
    endtask
 
endclass
 
 
 
//======================================================
// DRIVER
//======================================================
 
class driver;
 
    virtual vending_if vif;
 
    mailbox #(transaction) gen2drv;
 
    function new(
        virtual vending_if vif,
        mailbox #(transaction) gen2drv
    );
 
        this.vif = vif;
        this.gen2drv = gen2drv;
 
    endfunction
 
 
    task run();
 
        transaction tr;
 
        forever begin
 
            gen2drv.get(tr);
 
            // Drive inputs before the next positive edge
            @(negedge vif.clk);
 
            vif.coin_5  = tr.coin_5;
            vif.coin_10 = tr.coin_10;
            vif.coin_20 = tr.coin_20;
 
            @(negedge vif.clk);
 
            // Remove coin
            vif.coin_5  = 1'b0;
            vif.coin_10 = 1'b0;
            vif.coin_20 = 1'b0;
 
        end
 
    endtask
 
endclass
 
 
 
//======================================================
// MONITOR
//======================================================
 
class monitor;
 
    virtual vending_if vif;
 
    mailbox #(transaction) mon2scb;
 
    function new(
        virtual vending_if vif,
        mailbox #(transaction) mon2scb
    );
 
        this.vif = vif;
        this.mon2scb = mon2scb;
 
    endfunction
 
 
    task run();
 
        transaction tr;
 
        forever begin
 
            @(posedge vif.clk);
 
            tr = new();
 
            tr.coin_5  = vif.coin_5;
            tr.coin_10 = vif.coin_10;
            tr.coin_20 = vif.coin_20;
 
            mon2scb.put(tr);
 
        end
 
    endtask
 
endclass
 
 
 
//======================================================
// SCOREBOARD
//======================================================
 
class scoreboard;
 
    virtual vending_if vif;
 
    mailbox #(transaction) mon2scb;
 
    typedef enum logic [1:0] {
        EXP_IDLE_0   = 2'b00,
        EXP_MONEY_5  = 2'b01,
        EXP_MONEY_10 = 2'b10
    } exp_state_t;
 
    exp_state_t exp_state;
 
    int pass_count;
    int fail_count;
 
 
    function new(
        virtual vending_if vif,
        mailbox #(transaction) mon2scb
    );
 
        this.vif = vif;
        this.mon2scb = mon2scb;
 
        exp_state = EXP_IDLE_0;
 
        pass_count = 0;
        fail_count = 0;
 
    endfunction
 
 
    task run();
 
        transaction tr;
 
        logic exp_dispense;
        logic exp_change_5;
        exp_state_t exp_next_state;
 
        forever begin
 
            mon2scb.get(tr);
 
 
            //==========================================
            // RESET
            //==========================================
 
            if (vif.reset) begin
 
                exp_state = EXP_IDLE_0;
 
                continue;
 
            end
 
 
            //==========================================
            // OUTPUT LOGIC
            //==========================================
 
            exp_dispense = 1'b0;
            exp_change_5 = 1'b0;
 
            case (exp_state)
 
                EXP_IDLE_0: begin
 
                    if (tr.coin_20) begin
                        exp_dispense = 1'b1;
                        exp_change_5 = 1'b1;
                    end
 
                end
 
                EXP_MONEY_5: begin
 
                    if (tr.coin_10) begin
                        exp_dispense = 1'b1;
                    end
 
                    // coin_20 while ₹5 already in ->
                    // DUT silently ignores it
 
                end
 
                EXP_MONEY_10: begin
 
                    if (tr.coin_5) begin
                        exp_dispense = 1'b1;
                    end
                    else if (tr.coin_10) begin
                        exp_dispense = 1'b1;
                        exp_change_5 = 1'b1;
                    end
 
                    // coin_20 while ₹10 already in ->
                    // also silently ignored
 
                end
 
                default: begin
                    exp_dispense = 1'b0;
                    exp_change_5 = 1'b0;
                end
 
            endcase
 
 
            //==========================================
            // NEXT-STATE LOGIC
            //==========================================
 
            exp_next_state = exp_state;
 
            case (exp_state)
 
                EXP_IDLE_0: begin
 
                    if (tr.coin_5)
                        exp_next_state = EXP_MONEY_5;
                    else if (tr.coin_10)
                        exp_next_state = EXP_MONEY_10;
                    else if (tr.coin_20)
                        exp_next_state = EXP_IDLE_0;
 
                end
 
                EXP_MONEY_5: begin
 
                    if (tr.coin_5)
                        exp_next_state = EXP_MONEY_10;
                    else if (tr.coin_10)
                        exp_next_state = EXP_IDLE_0;
                    else
                        exp_next_state = EXP_MONEY_5;
 
                end
 
                EXP_MONEY_10: begin
 
                    if (tr.coin_5)
                        exp_next_state = EXP_IDLE_0;
                    else if (tr.coin_10)
                        exp_next_state = EXP_IDLE_0;
                    else
                        exp_next_state = EXP_MONEY_10;
 
                end
 
                default:
                    exp_next_state = EXP_IDLE_0;
 
            endcase
 
 
            //==========================================
            // COMPARE AGAINST DUT
            //==========================================
 
            if (vif.dispense !== exp_dispense) begin
 
                $error(
                    "FAIL: dispense mismatch. state=%s coin5=%0d coin10=%0d coin20=%0d expected=%0b actual=%0b",
                    exp_state.name(),
                    tr.coin_5, tr.coin_10, tr.coin_20,
                    exp_dispense, vif.dispense
                );
 
                fail_count++;
 
            end
            else begin
 
                $display(
                    "PASS: dispense OK (state=%s coin5=%0d coin10=%0d coin20=%0d)",
                    exp_state.name(), tr.coin_5, tr.coin_10, tr.coin_20
                );
 
                pass_count++;
 
            end
 
 
            if (vif.change_5 !== exp_change_5) begin
 
                $error(
                    "FAIL: change_5 mismatch. state=%s coin5=%0d coin10=%0d coin20=%0d expected=%0b actual=%0b",
                    exp_state.name(),
                    tr.coin_5, tr.coin_10, tr.coin_20,
                    exp_change_5, vif.change_5
                );
 
                fail_count++;
 
            end
            else begin
 
                pass_count++;
 
            end
 
 
            //==========================================
            // ADVANCE GOLDEN STATE
            //==========================================
 
            exp_state = exp_next_state;
 
        end
 
    endtask
 
endclass
 
 
 
//======================================================
// FUNCTIONAL COVERAGE
//======================================================
 
class coverage;
 
    virtual vending_if vif;
 
 
    covergroup vending_cg @(posedge vif.clk);
 
        //==============================================
        // COIN COVERAGE
        //==============================================
 
        coin_cp: coverpoint {
            vif.coin_5,
            vif.coin_10,
            vif.coin_20
        }
        {
 
            bins no_coin = {3'b000};
 
            bins coin_5 = {3'b100};
 
            bins coin_10 = {3'b010};
 
            bins coin_20 = {3'b001};
 
        }
 
 
        //==============================================
        // DISPENSE COVERAGE
        //==============================================
 
        dispense_cp: coverpoint vif.dispense {
 
            bins no_dispense = {1'b0};
 
            bins dispense = {1'b1};
 
        }
 
 
        //==============================================
        // CHANGE COVERAGE
        //==============================================
 
        change_cp: coverpoint vif.change_5 {
 
            bins no_change = {1'b0};
 
            bins change = {1'b1};
 
        }
 
    endgroup
 
 
    function new(virtual vending_if vif);
 
        this.vif = vif;
 
        vending_cg = new();
 
    endfunction
 
endclass
 
 
 
//======================================================
// ASSERTIONS
//======================================================
 
module vending_assertions(vending_if vif);
 
 
    // Only one coin can be inserted at a time
    property one_coin_only;
 
        @(posedge vif.clk)
 
        $onehot0({
            vif.coin_5,
            vif.coin_10,
            vif.coin_20
        });
 
    endproperty
 
 
    assert property(one_coin_only)
 
        else $error(
            "ASSERTION FAILED: Multiple coins inserted"
        );
 
 
    // Change must always be accompanied by dispense
    property change_requires_dispense;
 
        @(posedge vif.clk)
 
        vif.change_5 |-> vif.dispense;
 
    endproperty
 
 
    assert property(change_requires_dispense)
 
        else $error(
            "ASSERTION FAILED: Change without dispense"
        );
 
 
endmodule
 
 
 
//======================================================
// TOP TESTBENCH
//======================================================
 
module vending_machine_tb;
 
    logic clk;
 
 
    //==================================================
    // CLOCK
    //==================================================
 
    initial begin
 
        clk = 1'b0;
 
        forever #5 clk = ~clk;
 
    end
 
 
    //==================================================
    // INTERFACE
    //==================================================
 
    vending_if vif(clk);
 
 
    //==================================================
    // DUT
    //==================================================
 
    vending_machine dut (
 
        .clk       (clk),
 
        .reset     (vif.reset),
 
        .coin_5    (vif.coin_5),
 
        .coin_10   (vif.coin_10),
 
        .coin_20   (vif.coin_20),
 
        .dispense  (vif.dispense),
 
        .change_5  (vif.change_5)
 
    );
 
 
    //==================================================
    // ASSERTIONS
    //==================================================
 
    vending_assertions assertions(vif);
 
 
    //==================================================
    // MAILBOXES
    //==================================================
 
    mailbox #(transaction) gen2drv;
 
    mailbox #(transaction) mon2scb;
 
 
    //==================================================
    // VERIFICATION COMPONENTS
    //==================================================
 
    generator  gen;
 
    driver     drv;
 
    monitor    mon;
 
    scoreboard scb;
 
    coverage   cov;
 
 
    //==================================================
    // TEST
    //==================================================
 
    initial begin
 
        //==============================================
        // VCD DUMP
        //==============================================
 
        $dumpfile("dump.vcd");
 
        $dumpvars(0, vending_machine_tb);
 
 
        //==============================================
        // CREATE MAILBOXES
        //==============================================
 
        gen2drv = new();
 
        mon2scb = new();
 
 
        //==============================================
        // CREATE COMPONENTS
        //==============================================
 
        gen = new(gen2drv);
 
        drv = new(
            vif,
            gen2drv
        );
 
        mon = new(
            vif,
            mon2scb
        );
 
        scb = new(
            vif,
            mon2scb
        );
 
        cov = new(vif);
 
 
        //==============================================
        // INITIAL VALUES
        //==============================================
 
        vif.reset   = 1'b1;
 
        vif.coin_5  = 1'b0;
 
        vif.coin_10 = 1'b0;
 
        vif.coin_20 = 1'b0;
 
 
        //==============================================
        // RESET
        //==============================================
 
        repeat (2)
 
            @(posedge clk);
 
 
        vif.reset = 1'b0;
 
 
        //==============================================
        // START VERIFICATION
        //==============================================
 
        fork
 
            gen.run();
 
            drv.run();
 
            mon.run();
 
            scb.run();
 
        join_none
 
 
        //==============================================
        // RUN SIMULATION
        //==============================================
 
        #2000;
 
 
        //==============================================
        // PRINT RESULTS
        //==============================================
 
        $display("");
        $display("==============================================");
        $display("           VERIFICATION RESULT");
        $display("==============================================");
 
        $display(
            "PASS COUNT : %0d",
            scb.pass_count
        );
 
        $display(
            "FAIL COUNT : %0d",
            scb.fail_count
        );
 
        $display(
            "COVERAGE   : %0.2f%%",
            cov.vending_cg.get_coverage()
        );
 
        $display("==============================================");
 
 
        //==============================================
        // END SIMULATION
        //==============================================
 
        $finish;
 
    end
 
endmodule