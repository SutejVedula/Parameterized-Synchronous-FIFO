`timescale 1ns / 1ps

module fifo_tb;

    localparam int DATA_WIDTH  = 8;
    localparam int FIFO_DEPTH  = 16;
    localparam int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);

    logic clk = 0;
    logic reset;
    logic wr_en;
    logic rd_en;
    logic [DATA_WIDTH-1:0] data_in;

    logic [DATA_WIDTH-1:0] data_out;
    logic full;
    logic empty;
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
        begin
            if (condition) begin
                tests_passed++;
                $display("PASS: %s", description);
            end
            else begin
                tests_failed++;
                $error("FAIL: %s", description);
            end
        end
    endtask

    task automatic check_status(input string description);
        begin
            #1;
            check(
                (count == expected_queue.size()) &&
                (empty == (expected_queue.size() == 0)) &&
                (full == (expected_queue.size() == FIFO_DEPTH)),
                description
            );
        end
    endtask

    task automatic apply_reset;
        begin
            @(negedge clk);
            reset = 1;
            wr_en = 0;
            rd_en = 0;
            data_in = 0;

            repeat (2) @(negedge clk);

            expected_queue.delete();
            reset = 0;

            @(posedge clk);
            #1;

            check_status("Reset clears occupancy and status");
            check(data_out == 0, "Reset clears data_out");
        end
    endtask

    task automatic write_byte(input logic [7:0] value);
        bit should_accept;
        begin
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
                $sformatf("Write 0x%02h occupancy/status", value)
            );

            check(
                (should_accept && expected_queue.size() > 0) ||
                (!should_accept && expected_queue.size() == FIFO_DEPTH),
                $sformatf("Write acceptance policy for 0x%02h", value)
            );

            @(negedge clk);
            wr_en = 0;
        end
    endtask

    task automatic read_byte;
        logic [7:0] expected;
        bit should_accept;
        begin
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
                        "Read expected 0x%02h, received 0x%02h",
                        expected, data_out
                    )
                );
            end
            else begin
                check(
                    count == 0,
                    "Underflow rejected: occupancy remains zero"
                );
                check(
                    empty == 1,
                    "Underflow rejected: empty remains asserted"
                );
            end

            check_status("Read occupancy/status");

            @(negedge clk);
            rd_en = 0;
        end
    endtask

    initial begin
        reset = 0;
        wr_en = 0;
        rd_en = 0;
        data_in = 0;

        $display("======================================");
        $display(" FIFO BOUNDARY VERIFICATION");
        $display("======================================");

        // Test 1: Reset
        apply_reset();

        // Test 2: Basic ordering
        write_byte(8'hA5);
        write_byte(8'h12);
        write_byte(8'h34);

        read_byte();
        read_byte();
        read_byte();

        // Test 3: Underflow
        read_byte();

        // Test 4: Fill FIFO
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_byte(i);

        check(full == 1, "FIFO asserts full at capacity");
        check(count == FIFO_DEPTH, "Occupancy reaches FIFO depth");

        // Test 5: Overflow attempt
        write_byte(8'hEE);

        check(full == 1, "FIFO remains full after rejected write");

        // Check all original entries survived the overflow attempt
        for (int i = 0; i < FIFO_DEPTH; i++)
            read_byte();

        check(empty == 1, "FIFO empty after draining");

        // Test 6: Genuine pointer wraparound
        // Write 12, read 8, then write 12 more.
        // Both pointers must wrap around the memory array.
        for (int i = 0; i < 12; i++)
            write_byte(8'h20 + i);

        for (int i = 0; i < 8; i++)
            read_byte();

        for (int i = 0; i < 12; i++)
            write_byte(8'h60 + i);

        // The FIFO now contains the last four original entries
        // followed by the twelve newly written entries.
        for (int i = 8; i < 12; i++)
            read_byte();

        for (int i = 0; i < 12; i++)
            read_byte();

        check(empty == 1, "FIFO empty after wraparound test");

        // Test 7: Simultaneous read/write while nonempty
        write_byte(8'hA1);
        write_byte(8'hB2);

        @(negedge clk);
        wr_en = 1;
        rd_en = 1;
        data_in = 8'hC3;

        @(posedge clk);
        #1;

        check(data_out == 8'hA1,
              "Simultaneous read returns oldest data");

        expected_queue.pop_front();
        expected_queue.push_back(8'hC3);

        check_status("Simultaneous read/write occupancy");

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        read_byte();
        read_byte();

        // Test 8: Simultaneous read/write while full
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_byte(8'h80 + i);

        @(negedge clk);
        wr_en = 1;
        rd_en = 1;
        data_in = 8'hF0;

        @(posedge clk);
        #1;

        check(
            data_out == 8'h80,
            "Full FIFO simultaneous operation reads oldest data"
        );

        expected_queue.pop_front();
        expected_queue.push_back(8'hF0);

        check_status("Full FIFO simultaneous occupancy");

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        for (int i = 0; i < FIFO_DEPTH; i++)
            read_byte();

        check(empty == 1, "Final FIFO state is empty");

        $display("======================================");
        $display(" FIFO VERIFICATION SUMMARY");
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
