`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;

  logic [4:0] cnt;
  logic [9:0] q_out;

  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  wire [3:0] bits = $countones(q_m[7:0]);

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      cnt <= 0;
      q_out <= 0;
    end else if (ve_in == 0) begin
      case (control_in)
        2'b00 : q_out <= 10'b1101010100;
        2'b01 : q_out <= 10'b0010101011;
        2'b10 : q_out <= 10'b0101010100;
        default: q_out <= 10'b1010101011;
      endcase
      cnt <= 0;
    end else begin
      if (cnt == 0 || bits == 4) begin
        q_out[9] <= !q_m[8];
        q_out[8] <= q_m[8];
        q_out[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
        if (q_m[8] == 0) begin
          cnt <= cnt + 8 - 2*bits;
        end else begin
          cnt <= cnt + 2*bits - 8;
        end
      end else if ((!cnt[4] && bits > 4)
        || (cnt[4] && bits < 4)
      ) begin
        q_out[9] <= 1;
        q_out[8] <= q_m[8];
        q_out[7:0] <= ~q_m[7:0];
        cnt <= cnt + 2*q_m[8] + 8 - 2*bits;
      end else begin
        q_out[9] <= 0;
        q_out[8] <= q_m[8];
        q_out[7:0] <= q_m[7:0];
        cnt <= cnt - 2*(!q_m[8]) + 2*bits - 8;
      end
    end
  end
  assign tmds_out = q_out;

endmodule

function automatic [3:0] bitcnt;
  input [7:0] a;
  begin
    bitcnt = 0;
    for (int i = 0; i < 8; i += 1) begin
      if (a & (1 << i)) begin
        bitcnt += 1;
      end
    end
  end
endfunction

module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  wire [3:0] bits = $countones(data_in);

  always_comb begin
    // first count number of bits in data_in
    if (bits > 4 || (bits == 4 && !data_in[0])) begin
      qm_out[0] = data_in[0];
      for (int i = 1; i < 8; i += 1) begin
        qm_out[i] = !(data_in[i] ^ qm_out[i-1]);
      end
      qm_out[8] = 0;
    end else begin
      qm_out[0] = data_in[0];
      for (int i = 1; i < 8; i += 1) begin
        qm_out[i] = data_in[i] ^ qm_out[i-1];
      end
      qm_out[8] = 1;
    end
  end

endmodule

`default_nettype wire
