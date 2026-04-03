`timescale 1ns/1ps

module tb_top;
    logic clk = 0;
    always #5 clk = ~clk;

    gen_if vif (.clk(clk));

    dds_core dut (
        .bus(vif.dut)
    );

    Environment env;

    initial begin
        env.reset();

        env = new(vif.tb);

        env.gen.repeat_count = 50;

        env.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end
endmodule