// Copyright 2014-2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module register_file_1r_1w_be_dift
#(
    parameter ADDR_WIDTH    = 5,
    parameter DATA_WIDTH    = 32,
    parameter NUM_BYTE      = DATA_WIDTH/8
)
(
    input  logic                                clk,

    // Read port
    input  logic                                ReadEnable,
    input  logic [ADDR_WIDTH-1:0]               ReadAddr,
    output logic [DATA_WIDTH-1:0]               ReadData,
    output logic [NUM_BYTE-1:0]                 ReadTag,

    // Write port
    input  logic                                WriteEnable,
    input  logic [ADDR_WIDTH-1:0]               WriteAddr,
    input  logic [NUM_BYTE-1:0][7:0]            WriteData,
    input  logic [NUM_BYTE-1:0]                 WriteTag,
    input  logic [NUM_BYTE-1:0]                 WriteBE
);

    localparam    NUM_WORDS = 2**ADDR_WIDTH;

    // Read address register, located at the input of the address decoder
    logic [ADDR_WIDTH-1:0]                         RAddrRegxDP;
    logic [NUM_WORDS-1:0]                          RAddrOneHotxD;

    logic [NUM_BYTE-1:0][7:0]                      MemContentxDP[NUM_WORDS];
    logic [NUM_BYTE-1:0]                           MemContentTagxDP[NUM_WORDS];

    logic [NUM_WORDS-1:0][NUM_BYTE-1:0]            WAddrOneHotxD;
    logic [NUM_WORDS-1:0][NUM_BYTE-1:0]            ClocksxC;
    logic [NUM_BYTE-1:0][7:0]                      WDataIntxD;
    logic [NUM_BYTE-1:0]                           WTagIntxD;

    logic                                          clk_int;

    int unsigned i;
    int unsigned j;
    int unsigned k;
    int unsigned l;
    int unsigned m;
    int unsigned n;
    int unsigned o;
    int unsigned p;

    genvar x;
    genvar y;

    cluster_clock_gating CG_WE_GLOBAL
    (
        .clk_o(clk_int),
        .en_i(WriteEnable),
        .test_en_i(1'b0),
        .clk_i(clk)
    );

    //-----------------------------------------------------------------------------
    //-- READ : Read address register
    //-----------------------------------------------------------------------------

    always_ff @(posedge clk)
    begin : p_RAddrReg
      if(ReadEnable)
        RAddrRegxDP <= ReadAddr;
    end


    //-----------------------------------------------------------------------------
    //-- READ : Read address decoder RAD
    //-----------------------------------------------------------------------------  
    always_comb
    begin : p_RAD
      RAddrOneHotxD = '0;
      RAddrOneHotxD[RAddrRegxDP] = 1'b1;
    end
    assign ReadData = MemContentxDP[RAddrRegxDP];
    assign ReadTag  = MemContentTagxDP[RAddrRegxDP];


    //-----------------------------------------------------------------------------
    //-- WRITE : Write Address Decoder (WAD), combinatorial process
    //-----------------------------------------------------------------------------
    always_comb
    begin : p_WAD
      for(i=0; i<NUM_WORDS; i++)
        begin : p_WordIter
            for(j=0; j<NUM_BYTE; j++)
              begin : p_ByteIter
                if ( (WriteEnable == 1'b1 ) && (WriteBE[j] == 1'b1) &&  (WriteAddr == i) )
                  WAddrOneHotxD[i][j] = 1'b1;
                else
                  WAddrOneHotxD[i][j] = 1'b0;
              end
        end
    end



    //-----------------------------------------------------------------------------
    //-- WRITE : Clock gating (if integrated clock-gating cells are available)
    //-----------------------------------------------------------------------------
    generate
    for(x=0; x<NUM_WORDS; x++)
      begin : CG_CELL_WORD_ITER
          for(y=0; y<NUM_BYTE; y++)
            begin : CG_CELL_BYTE_ITER
                cluster_clock_gating CG_Inst
                (
                  .clk_o(ClocksxC[x][y]),
                  .en_i(WAddrOneHotxD[x][y]),
                  .test_en_i(1'b0),
                  .clk_i(clk_int)
                  );
            end
      end
    endgenerate




    //-----------------------------------------------------------------------------
    // WRITE : SAMPLE INPUT DATA
    //---------------------------------------------------------------------------  
    always_ff @(posedge clk)
    begin : sample_waddr
      for(m=0; m<NUM_BYTE; m++)
        begin
            if(WriteEnable & WriteBE[m])
              WDataIntxD[m] <= WriteData[m];
        end
    end

    always_ff @(posedge clk)
    begin : sample_waddr_tag
      for(p=0; p<NUM_BYTE; p++)
        begin
            if(WriteEnable & WriteBE[p])
              WTagIntxD[p] <= WriteTag[p];
        end
    end



    //-----------------------------------------------------------------------------
    //-- WRITE : Write operation
    //-----------------------------------------------------------------------------  
    //-- Generate M = WORDS sequential processes, each of which describes one
    //-- word of the memory. The processes are synchronized with the clocks
    //-- ClocksxC(i), i = 0, 1, ..., M-1
    //-- Use active low, i.e. transparent on low latches as storage elements
    //-- Data is sampled on rising clock edge


    always_latch
    begin : latch_wdata
      for(k=0; k<NUM_WORDS; k++)
        begin : w_WordIter
            for(l=0; l<NUM_BYTE; l++)
              begin : w_ByteIter
                if( ClocksxC[k][l] == 1'b1)
                  MemContentxDP[k][l] = WDataIntxD[l];
              end
        end
    end
    
    always_latch
    begin : latch_wdata_tag
      for(n=0; n<NUM_WORDS; n++)
        begin : w_WordIter
            for(o=0; o<NUM_BYTE; o++)
              begin : w_ByteIter
                if( ClocksxC[n][o] == 1'b1)
                  MemContentTagxDP[n][o] = WTagIntxD[o];
              end
        end
    end


endmodule
