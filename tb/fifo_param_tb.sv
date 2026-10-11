
`timescale 1ns / 1ps

module fifo_param_tb;

    localparam int DATA_WIDTH  = 16;
    localparam int FIFO_DEPTH  = 8;
    localparam int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);

    logic clk = 0;
    logic reset = 0;
    logic wr_en = 0;
    logic rd_en = 0;

    logic [DATA_WIDTH-1:0] data_in = '0;
    logic [DATA_WIDTH-1:0] data_out;
    logic full, empty;
    logic [COUNT_WIDTH-1:0] count;

    int tests_passed = 0;
    int tests_failed = 0;

    logic [DATA_WIDTH-1:0] expected_queue[$];

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .count(count)
    );

    always #5 clk = ~clk;

    task automatic check(
        input bit condition,
        input string description
    );
        if (condition) begin
            tests_passed++;
            $display("PASS: %s", description);
        end else begin
            tests_failed++;
            $error("FAIL: %s", description);
        end
    endtask

    task automatic check_status(input string description);
        #1;
        check(
            (count == expected_queue.size()) &&
            (empty == (expected_queue.size() == 0)) &&
            (full == (expected_queue.size() == FIFO_DEPTH)),
            description
        );
    endtask

    task automatic apply_reset;
        @(negedge clk);
        reset = 1;
        wr_en = 0;
        rd_en = 0;
        data_in = '0;

        repeat (2) @(negedge clk);

        expected_queue.delete();
        reset = 0;

        @(posedge clk);
        #1;

        check_status("Reset clears occupancy and status");
        check(data_out == '0, "Reset clears data_out");
    endtask

    task automatic write_word(
        input logic [DATA_WIDTH-1:0] value
    );
        bit should_accept;

        @(negedge clk);
        wr_en = 1;
        rd_en = 0;
        data_in = value;

        should_accept = (expected_queue.size() < FIFO_DEPTH);

        @(posedge clk);

        if (should_accept)
            expected_queue.push_back(value);

        #1;
        check_status(
            $sformatf("Write 0x%0h occupancy/status", value)
        );

        check(
            should_accept || (expected_queue.size() == FIFO_DEPTH),
            $sformatf("Write acceptance policy for 0x%0h", value)
        );

        @(negedge clk);
        wr_en = 0;
    endtask

    task automatic read_word;
        logic [DATA_WIDTH-1:0] expected;
        bit should_accept;

        @(negedge clk);
        wr_en = 0;
        rd_en = 1;

        should_accept = (expected_queue.size() > 0);

        if (should_accept)
            expected = expected_queue.pop_front();

        @(posedge clk);
        #1;

        if (should_accept) begin
            check(
                data_out === expected,
                $sformatf(
                    "Read expected 0x%0h, received 0x%0h",
                    expected, data_out
                )
            );
        end else begin
            check(count == 0, "Underflow rejected: count stays zero");
            check(empty, "Underflow rejected: empty remains asserted");
        end

        check_status("Read occupancy/status");

        @(negedge clk);
        rd_en = 0;
    endtask

    initial begin
        $display("======================================");
        $display(" PARAMETERIZED FIFO VERIFICATION");
        $display(" DATA_WIDTH = %0d", DATA_WIDTH);
        $display(" FIFO_DEPTH = %0d", FIFO_DEPTH);
        $display("======================================");

        // Test 1: Reset
        apply_reset();

        // Test 2: Data ordering
        write_word(16'hA501);
        write_word(16'h1234);
        write_word(16'hBEEF);

        read_word();
        read_word();
        read_word();

        // Test 3: Underflow
        read_word();

        // Test 4: Fill to capacity
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_word(16'h1000 + i);

        check(full, "FIFO asserts full at capacity");
        check(count == FIFO_DEPTH, "Count equals configured depth");

        // Test 5: Overflow
        write_word(16'hEEEE);
        check(full, "FIFO remains full after overflow attempt");

        // Drain and check retained data
        for (int i = 0; i < FIFO_DEPTH; i++)
            read_word();

        check(empty, "FIFO empty after draining");

        // Test 6: Pointer wraparound
        // Fill, read half, refill half, then drain.
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_word(16'h2000 + i);

        for (int i = 0; i < FIFO_DEPTH/2; i++)
            read_word();

        for (int i = 0; i < FIFO_DEPTH/2; i++)
            write_word(16'h3000 + i);

        while (expected_queue.size() > 0)
            read_word();

        check(empty, "FIFO empty after wraparound test");

        // Test 7: Simultaneous read/write while nonempty
        write_word(16'hA101);
        write_word(16'hB202);

        @(negedge clk);
        wr_en = 1;
        rd_en = 1;
        data_in = 16'hC303;

        @(posedge clk);
        #1;

        check(
            data_out == 16'hA101,
            "Simultaneous operation reads oldest data"
        );

        expected_queue.pop_front();
        expected_queue.push_back(16'hC303);
        check_status("Simultaneous read/write occupancy");

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        read_word();
        read_word();

        // Test 8: Simultaneous read/write while full
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_word(16'h8000 + i);

        @(negedge clk);
        wr_en = 1;
        rd_en = 1;
        data_in = 16'hF00D;

        @(posedge clk);
        #1;

        check(
            data_out == 16'h8000,
            "Full FIFO simultaneous operation reads oldest data"
        );

        expected_queue.pop_front();
        expected_queue.push_back(16'hF00D);
        check_status("Full FIFO simultaneous occupancy");

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        for (int i = 0; i < FIFO_DEPTH; i++)
            read_word();

        check(empty, "Final FIFO state is empty");

        $display("======================================");
        $display(" PARAMETERIZED FIFO SUMMARY");
        $display(" Passed: %0d", tests_passed);
        $display(" Failed: %0d", tests_failed);
        $display("======================================");

        if (tests_failed == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: FAILURES DETECTED");

        $finish;
    end

endmodule
