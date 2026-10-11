
`timescale 1ns / 1ps

module fifo #(
    parameter int DATA_WIDTH  = 8,
    parameter int FIFO_DEPTH  = 16,
    parameter int PTR_WIDTH   = $clog2(FIFO_DEPTH),
    parameter int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1)
) (
    input  logic                   clk,
    input  logic                   reset,
    input  logic                   wr_en,
    input  logic                   rd_en,
    input  logic [DATA_WIDTH-1:0]  data_in,

    output logic [DATA_WIDTH-1:0]  data_out,
    output logic                   full,
    output logic                   empty,
    output logic [COUNT_WIDTH-1:0] count
);

    // FIFO storage
    logic [DATA_WIDTH-1:0] memory [0:FIFO_DEPTH-1];

    // Read and write pointers
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;

    // Accepted operations
    logic write_accept;
    logic read_accept;

    // Status flags
    assign empty = (count == 0);
    assign full  = (count == FIFO_DEPTH);

    // Read only when data is available
    assign read_accept = rd_en && !empty;

    // Write when space exists or a read is accepted
    assign write_accept = wr_en && (!full || read_accept);

    // Sequential FIFO logic
    always_ff @(posedge clk) begin
        if (reset) begin
            write_ptr <= '0;
            read_ptr  <= '0;
            count     <= '0;
            data_out  <= '0;
        end
        else begin

            // Write operation
            if (write_accept) begin
                memory[write_ptr] <= data_in;

                if (write_ptr == FIFO_DEPTH - 1)
                    write_ptr <= '0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            // Read operation
            if (read_accept) begin
                data_out <= memory[read_ptr];

                if (read_ptr == FIFO_DEPTH - 1)
                    read_ptr <= '0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            // Occupancy update
            case ({write_accept, read_accept})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

`ifndef SYNTHESIS

    // Enable assertions only after reset has initialized the FIFO.
    logic assertions_enabled = 1'b0;

    always_ff @(posedge clk) begin
        if (reset)
            assertions_enabled <= 1'b1;
    end

    // Assertion 1: Occupancy never exceeds capacity
    property p_count_within_capacity;
        @(posedge clk)
        disable iff (reset || !assertions_enabled)
        count <= FIFO_DEPTH;
    endproperty

    assert property (p_count_within_capacity)
        else $error("FIFO ASSERTION FAILED: count exceeds capacity");

    // Assertion 2: Empty flag agrees with occupancy
    property p_empty_matches_count;
        @(posedge clk)
        disable iff (reset || !assertions_enabled)
        empty == (count == 0);
    endproperty

    assert property (p_empty_matches_count)
        else $error("FIFO ASSERTION FAILED: empty flag mismatch");

    // Assertion 3: Full flag agrees with occupancy
    property p_full_matches_count;
        @(posedge clk)
        disable iff (reset || !assertions_enabled)
        full == (count == FIFO_DEPTH);
    endproperty

    assert property (p_full_matches_count)
        else $error("FIFO ASSERTION FAILED: full flag mismatch");

    // Assertion 4: Reset clears occupancy and status
    property p_reset_clears_count;
        @(posedge clk)
        reset |=> (count == 0 && empty && !full);
    endproperty

    assert property (p_reset_clears_count)
        else $error("FIFO ASSERTION FAILED: reset state incorrect");

`endif

endmodule
