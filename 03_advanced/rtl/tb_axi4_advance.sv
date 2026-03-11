`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Minh Luu
// 
// Create Date: 03/09/2026 08:58:16 AM
// Module Name: tb_axi4_advance
//
// Description: Advanced AXI4 testbench - 2 Masters x 2 Slaves via SmartConnect
//
//   TEST 1: Address Decode  - MST1 writes/reads to Slave 1 & Slave 2
//   TEST 2: Address Decode  - MST2 writes/reads to Slave 1 & Slave 2
//   TEST 3: Arbitration     - Both masters -> Slave 1 (simultaneous)
//   TEST 4: Arbitration     - Both masters -> Slave 2 (simultaneous)
//   TEST 5: Error Response  - SLVERR from Slave 2 on reserved address
//
// Address Map:
//   Slave 1: 0x44A0_0000 (M00_AXI) - memory-mode  (slv_mem_t)
//   Slave 2: 0x44A1_0000 (M01_AXI) - reactive-mode (slv_t, custom BRESP)
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_1_pkg::*;   // master 1
import design_1_axi_vip_0_2_pkg::*;   // master 2
import design_1_axi_vip_0_3_pkg::*;   // slave 1
import design_1_axi_vip_1_1_pkg::*;   // slave 2

module tb_axi4_advance();

    bit aclk    = 0;
    bit aresetn = 0;

    // 100MHz clock
    always #5ns aclk <= ~aclk;

    // declare agents
    design_1_axi_vip_0_1_mst_t      mst1_agent;
    design_1_axi_vip_0_2_mst_t      mst2_agent;
    design_1_axi_vip_0_3_slv_mem_t  slave_agent1;   // memory-mode
    design_1_axi_vip_1_1_slv_t      slave_agent2;   // reactive-mode

    design_1_wrapper DUT(
        .aclk   (aclk),
        .aresetn(aresetn)
    );

    localparam xil_axi_ulong SLAVE1_BASE        = 32'h44A0_0000;
    localparam xil_axi_ulong SLAVE2_BASE        = 32'h44A1_0000;
    localparam xil_axi_ulong SLV2_RESERVED_ADDR = SLAVE2_BASE + 32'h0F00;

    // Test 1 - MST1 address-decode
    localparam xil_axi_ulong MST1_SLV1_ADDR = SLAVE1_BASE;
    localparam xil_axi_ulong MST1_SLV2_ADDR = SLAVE2_BASE;
    localparam bit [31:0]    MST1_SLV1_DATA = 32'hAABB_1111;
    localparam bit [31:0]    MST1_SLV2_DATA = 32'hAABB_2222;

    // Test 2 - MST2 address-decode
    localparam xil_axi_ulong MST2_SLV1_ADDR = SLAVE1_BASE + 32'h0008;
    localparam xil_axi_ulong MST2_SLV2_ADDR = SLAVE2_BASE + 32'h0008;
    localparam bit [31:0]    MST2_SLV1_DATA = 32'hCCDD_3333;
    localparam bit [31:0]    MST2_SLV2_DATA = 32'hCCDD_4444;

    // Test 3 - Arbitration -> Slave 1
    localparam xil_axi_ulong ARB_SLV1_MST1_ADDR = SLAVE1_BASE + 32'h0010;
    localparam xil_axi_ulong ARB_SLV1_MST2_ADDR = SLAVE1_BASE + 32'h0014;
    localparam bit [31:0]    ARB_SLV1_MST1_DATA  = 32'h1111_AAAA;
    localparam bit [31:0]    ARB_SLV1_MST2_DATA  = 32'h2222_BBBB;

    // Test 4 - Arbitration -> Slave 2
    localparam xil_axi_ulong ARB_SLV2_MST1_ADDR = SLAVE2_BASE + 32'h0010;
    localparam xil_axi_ulong ARB_SLV2_MST2_ADDR = SLAVE2_BASE + 32'h0014;
    localparam bit [31:0]    ARB_SLV2_MST1_DATA  = 32'h3333_CCCC;
    localparam bit [31:0]    ARB_SLV2_MST2_DATA  = 32'h4444_DDDD;

    // Test 5 - SLVERR
    localparam bit [31:0]    SLVERR_TEST_DATA = 32'hBEEF_BEEF;

    // slave 2 local memory
    logic [31:0] slv2_mem [xil_axi_ulong];


    // Write via MST1
    task automatic mst1_write(input xil_axi_ulong addr, input bit [31:0] data);
        xil_axi_resp_t resp;
        mst1_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
        $display("[%0t] [MST1] Write | addr=0x%08h  data=0x%08h  resp=%s",
                 $time, addr, data, resp.name());
    endtask

    // Write via MST2
    task automatic mst2_write(input xil_axi_ulong addr, input bit [31:0] data);
        xil_axi_resp_t resp;
        mst2_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
        $display("[%0t] [MST2] Write | addr=0x%08h  data=0x%08h  resp=%s",
                 $time, addr, data, resp.name());
    endtask

    // Write via MST1 + verify response (for SLVERR / DECERR tests)
    task automatic mst1_write_check_resp(
        input xil_axi_ulong  addr,
        input bit [31:0]     data,
        input xil_axi_resp_t expected,
        input string         label
    );
        xil_axi_resp_t resp;
        mst1_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
        if (resp == expected)
            $display("[%0t] [PASS] %s | resp=%s", $time, label, resp.name());
        else
            $display("[%0t] [FAIL] %s | resp=%s (expected %s)  <-- MISMATCH",
                     $time, label, resp.name(), expected.name());
    endtask

    // Read via MST1 + verify data
    task automatic mst1_read_verify(
        input xil_axi_ulong addr,
        input bit [31:0]    expected,
        input string        label
    );
        bit [31:0] rd_data;  xil_axi_resp_t resp;
        mst1_agent.AXI4LITE_READ_BURST(addr, 0, rd_data, resp);
        if (rd_data == expected)
            $display("[%0t] [PASS] %s | got=0x%08h", $time, label, rd_data);
        else
            $display("[%0t] [FAIL] %s | expected=0x%08h  got=0x%08h  <-- MISMATCH",
                     $time, label, expected, rd_data);
    endtask

    // Read via MST2 + verify data
    task automatic mst2_read_verify(
        input xil_axi_ulong addr,
        input bit [31:0]    expected,
        input string        label
    );
        bit [31:0] rd_data;  xil_axi_resp_t resp;
        mst2_agent.AXI4LITE_READ_BURST(addr, 0, rd_data, resp);
        if (rd_data == expected)
            $display("[%0t] [PASS] %s | got=0x%08h", $time, label, rd_data);
        else
            $display("[%0t] [FAIL] %s | expected=0x%08h  got=0x%08h  <-- MISMATCH",
                     $time, label, expected, rd_data);
    endtask

    //  Slave 2 - Reactive write handler
    //    Normal region  -> store data, respond OKAY
    //    Reserved 0x0F00 -> discard data, respond SLVERR
    initial begin : SLV2_WR_HANDLER
        axi_transaction wr_reactive;
        xil_axi_ulong   addr;

        wait (slave_agent2 != null);
        @(posedge aresetn);

        forever begin
            slave_agent2.wr_driver.get_wr_reactive(wr_reactive);
            addr = wr_reactive.get_addr();

            if (addr >= SLV2_RESERVED_ADDR && addr < SLV2_RESERVED_ADDR + 32'h0100) begin
                wr_reactive.set_bresp(XIL_AXI_RESP_SLVERR);
                $display("[%0t] [SLAVE2] SLVERR | addr=0x%08h (reserved)", $time, addr);
            end else begin
                slv2_mem[addr] = wr_reactive.get_data_beat(0);
                wr_reactive.set_bresp(XIL_AXI_RESP_OKAY);
            end

            wr_reactive.set_response_delay(1);
            slave_agent2.wr_driver.send(wr_reactive);
        end
    end

    //  Slave 2 - Reactive read handler
    //    Normal region  -> return data from slv2_mem[], respond OKAY
    //    Reserved 0x0F00 -> return 0, respond SLVERR
    initial begin : SLV2_RD_HANDLER
        axi_transaction   rd_reactive;
        xil_axi_ulong     addr;
        xil_axi_data_beat rd_beat;

        wait (slave_agent2 != null);
        @(posedge aresetn);

        forever begin
            slave_agent2.rd_driver.get_rd_reactive(rd_reactive);
            addr = rd_reactive.get_addr();

            if (addr >= SLV2_RESERVED_ADDR && addr < SLV2_RESERVED_ADDR + 32'h0100) begin
                rd_reactive.set_data_beat(0, 32'h0);
                rd_reactive.set_rresp(0, XIL_AXI_RESP_SLVERR);
                $display("[%0t] [SLAVE2] SLVERR read | addr=0x%08h (reserved)", $time, addr);
            end else begin
                rd_beat = slv2_mem.exists(addr) ? slv2_mem[addr] : 32'h0;
                rd_reactive.set_data_beat(0, rd_beat);
                rd_reactive.set_rresp(0, XIL_AXI_RESP_OKAY);
            end

            slave_agent2.rd_driver.send(rd_reactive);
        end
    end

    initial begin
        // agent setup
        mst1_agent   = new("master1 vip agent", DUT.design_1_i.axi_vip_master1.inst.IF);
        mst2_agent   = new("master2 vip agent", DUT.design_1_i.axi_vip_master2.inst.IF);
        slave_agent1 = new("slave vip1 agent",  DUT.design_1_i.axi_vip_slave1.inst.IF);
        slave_agent2 = new("slave vip2 agent",  DUT.design_1_i.axi_vip_slave2.inst.IF);

        mst1_agent.set_agent_tag("MST1");
        mst2_agent.set_agent_tag("MST2");
        slave_agent1.set_agent_tag("SLAVE_1");
        slave_agent2.set_agent_tag("SLAVE_2");

        mst1_agent.start_master();
        mst2_agent.start_master();
        slave_agent1.start_slave();     // memory-mode  (auto OKAY)
        slave_agent2.start_slave();     // reactive-mode (SLV2_WR/RD_HANDLER)

        aresetn = 0;  #50;
        aresetn = 1;  #20;

        // TEST 1: Address Decode - MST1 -> Slave 1 & Slave 2
        $display("\n############################################################");
        $display("#  TEST 1: Address Decode - MST1 writes to both slaves     #");
        $display("############################################################\n");

        mst1_write(MST1_SLV1_ADDR, MST1_SLV1_DATA);  #20;
        mst1_write(MST1_SLV2_ADDR, MST1_SLV2_DATA);  #50;

        mst1_read_verify(MST1_SLV1_ADDR, MST1_SLV1_DATA, "MST1->SLV1");  #20;
        mst1_read_verify(MST1_SLV2_ADDR, MST1_SLV2_DATA, "MST1->SLV2");  #50;

        // TEST 2: Address Decode - MST2 -> Slave 1 & Slave 2
        $display("\n############################################################");
        $display("#  TEST 2: Address Decode - MST2 writes to both slaves     #");
        $display("############################################################\n");

        mst2_write(MST2_SLV1_ADDR, MST2_SLV1_DATA);  #20;
        mst2_write(MST2_SLV2_ADDR, MST2_SLV2_DATA);  #50;

        mst2_read_verify(MST2_SLV1_ADDR, MST2_SLV1_DATA, "MST2->SLV1");  #20;
        mst2_read_verify(MST2_SLV2_ADDR, MST2_SLV2_DATA, "MST2->SLV2");  #50;

        // TEST 3: Multi-Master Arbitration -> Slave 1
        $display("\n############################################################");
        $display("#  TEST 3: Multi-Master Arbitration -> Slave 1              #");
        $display("############################################################\n");

        fork
            mst1_write(ARB_SLV1_MST1_ADDR, ARB_SLV1_MST1_DATA);
            mst2_write(ARB_SLV1_MST2_ADDR, ARB_SLV1_MST2_DATA);
        join
        #50;

        mst1_read_verify(ARB_SLV1_MST1_ADDR, ARB_SLV1_MST1_DATA, "ARB MST1->SLV1");  #20;
        mst1_read_verify(ARB_SLV1_MST2_ADDR, ARB_SLV1_MST2_DATA, "ARB MST2->SLV1");  #50;

        // TEST 4: Multi-Master Arbitration -> Slave 2
        $display("\n############################################################");
        $display("#  TEST 4: Multi-Master Arbitration -> Slave 2              #");
        $display("############################################################\n");

        fork
            mst1_write(ARB_SLV2_MST1_ADDR, ARB_SLV2_MST1_DATA);
            mst2_write(ARB_SLV2_MST2_ADDR, ARB_SLV2_MST2_DATA);
        join
        #50;

        mst1_read_verify(ARB_SLV2_MST1_ADDR, ARB_SLV2_MST1_DATA, "ARB MST1->SLV2");  #20;
        mst1_read_verify(ARB_SLV2_MST2_ADDR, ARB_SLV2_MST2_DATA, "ARB MST2->SLV2");  #50;

        // TEST 5: Error Response - SLVERR from Slave 2 (reserved address)
        //   The reactive handler returns BRESP=SLVERR for addr 0x44A1_0F00.
        //   In real HW this could be a write to a read-only register.
        $display("\n############################################################");
        $display("#  TEST 5: Error Response - SLVERR (Slave 2)               #");
        $display("############################################################\n");

        // Write to reserved address - expect SLVERR
        mst1_write_check_resp(SLV2_RESERVED_ADDR, SLVERR_TEST_DATA,
                              XIL_AXI_RESP_SLVERR, "SLVERR write (0x44A1_0F00)");
        #50;

        // Sanity: normal write still returns OKAY after the error
        mst1_write_check_resp(SLAVE2_BASE + 32'h0020, 32'hAFFA_FFAA,
                              XIL_AXI_RESP_OKAY, "Normal write after SLVERR");
        #20;
        mst1_read_verify(SLAVE2_BASE + 32'h0020, 32'hAFFA_FFAA,
                          "Read-back after SLVERR test");

        $display("\n############################################################");
        $display("#               ALL TESTS COMPLETE                         #");
        $display("############################################################\n");

        #200;
        $finish;
    end

endmodule
