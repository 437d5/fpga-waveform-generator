class SignalItem;
    rand enum {SINE, SQUARE, TRIANGLE, SAW} sig_type;
    rand int frequency;
    rand byte amplitude;

    rand int offset;
    rand int duty_threshold;

    constraint freq_range {
        frequency inside {[100:1000000]};
    }

    constraint amp_limit {
        amplitude > 0;
    }

    constraint offset_limit {
        offset inside {[-8192:8191]};
    }

    constraint duty_c {
        if (sig_type == SQUARE) {
            duty_threshold inside {[1000:2000000000]};
        } else {
            duty_threshold == 0;
        } 
    }

    function void display(string name);
        $display("-----------------------------------------");
        $display("[%s] Generated Transaction:", name);
        $display("  Type  : %s", sig_type.name());
        $display("  Freq  : %0d Hz", frequency);
        $display("  Amp   : %0d", amplitude);
        $display("  Offset: %0d", offset);
        
        if (sig_type == SQUARE) begin
            $display("  Duty  : %0d", duty_threshold);
        end
        $display("-----------------------------------------");
    endfunction
endclass

class Generator;
    mailbox gen2drv; // generator to driver

    event ended; // end of generation

    int repeat_count = 10;

    function new(mailbox gen2drv, event ended);
        this.gen2drv = gen2drv;
        this.ended = ended;
    endfunction

    task run();
        SignalItem item;

        $display("-----------------------------------------");
        $display("[Generator] Starting generation of %0d items", repeat_count);
        $display("-----------------------------------------");

        for (int i = 0; i < repeat_count; i++) begin
            item = new();

            if (!item.randomize()) begin
                $fatal(1, "[Generator] Randomization failed! Check constraints.");
            end

            item.display($sformat("Generator %0d/%0d", i+1, repeat_count));

            gen2drv.put(item);
        end

        $display("[Generator] Finished generating items.");

        -> ended;
    endtask

endclass

class Driver;
    virtual gen_if.tb vif;

    mailbox gen2drv;

    localparam real CLK_FREQ = 100000000.0;
    localparam int PHASE_W = 32;

    function new(virtual gen_if.tb vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        $display("[Driver] Starting to drive signals...");

        forever begin
            SignalItem item;
            logic [PHASE_W-1:0] calculated_phase_step;

            gen2drv.get(item);

            calculated_phase_step = (item.frequency * (2.0 ** PHASE_W)) / CLK_FREQ;

            @(posedge vif.clk);

            vif.amplitude      <= item.amplitude;
            vif.offset         <= item.offset;
            vif.duty_threshold <= item.duty_threshold;
            vif.phase_step     <= calculated_phase_step;
            
            vif.wave_sel <= item.sig_type;

            repeat(100) @(posedge vif.clk);

            $display("[Driver] Driven Item. Type: %s, Freq: %0d Hz (Step: %0h)",
                     item.sig_type.name(), item.frequency, calculated_phase_step);
        end
    endtask
endclass

class Environment;
    Generator gen;
    Driver drv;

    mailbox gen2drv;

    event ended;

    virtual gen_if.tb vif;

    function new(virtual gen_if.tb vif);
        this.vif = vif;

        gen2drv = new();

        gen = new(gen2drv, ended);
        drv = new(vif, gen2drv);

    endfunction

    task reset();
        $display("[Environment] Asserting Reset...");
        vif.rst <= 1;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 0;
        @(posedge vif.clk);
        $display("[Environment] Reset De-asserted. DUT is ready.");
    endtask

    task run();
        $display("=========================================");
        $display("[Environment] Starting Simulation...");
        $display("=========================================");

        reset();

        fork
            gen.run();
            drv.run();
        join_none

        wait(ended.triggered);

        #100;

        $display("=========================================");
        $display("[Environment] Simulation Finished!");
        $display("=========================================");

        $finish;
    endtask
endclass

