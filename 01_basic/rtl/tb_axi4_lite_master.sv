`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Minh Luu
// 
// Create Date: 02/25/2026 08:34:19 AM
// Design Name: 
// Module Name: tb_axi4_lite_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
Monitors for the AXI VIP (master, pass-through, and slave) are always on and collect all of the information from the interfaces.
*/

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*; // master
import design_1_axi_vip_1_1_pkg::*; // slave
import design_1_axi_vip_0_1_pkg::*; // passthrough
// import axi_vip_slave_pkg::*;

// master agent: design_1_axi_vip_0_0_mst_t::*
// passthrough agent: design_1_axi_vip_1_0_passthrough_t::*
// slave agent: design_1_axi_vip_1_1_slv_t::* 

module tb_axi4_master();

	bit aclk = 0;
	bit aresetn = 1;
	
	// declare agent
	design_1_axi_vip_0_0_mst_t mst_agent;
	design_1_axi_vip_1_1_slv_mem_t slv_mem_agent;
	design_1_axi_vip_0_1_passthrough_t passthrough_agent;
	
	// 100MHz
	always #5ns aclk <= ~aclk;

	// instantiate block diagram
	design_1_wrapper DUT(
		.aclk(aclk),
		.aresetn(aresetn)
	);

	// declare testbench signals
	xil_axi_resp_t 	    resp;
	xil_axi_ulong  	    addr = 32'h44A0_0000, addr2 = 32'h44A0_0004;
	xil_axi_prot_t  	prot = 0;
	bit [31:0]          data_wr = 32'hDEADBEEF, data_wr2 = 32'hABCD_EF01;
	bit [31:0] 		    data_rd, data_rd2;
	
	initial begin
		// create agents
		mst_agent = new("master vip agent", DUT.design_1_i.axi_vip_master.inst.IF);
		slv_mem_agent = new("slave mem vip agent", DUT.design_1_i.axi_vip_slave.inst.IF);
		passthrough_agent = new("passthrough vip agent", DUT.design_1_i.axi_vip_passthrough.inst.IF);
		
		// set tag agents
		mst_agent.set_agent_tag("master vip");
		mst_agent.set_verbosity(400);
		
		slv_mem_agent.set_agent_tag("slave mem vip");
		slv_mem_agent.set_verbosity(400);
		
		passthrough_agent.set_agent_tag("pass agent vip");
		passthrough_agent.set_verbosity(400); 
		
		// start the agent
		mst_agent.start_master();
		slv_mem_agent.start_slave();
		
		// set passthrough agent mode
		DUT.design_1_i.axi_vip_passthrough.inst.set_passthrough_mode();
		
		aresetn = 0;
		#20;
		aresetn = 1;
		#20;
		
		$display("");
		$display("################################################################");
		$display("#                  single write/read AXI4-LITE                 #");
		$display("################################################################");
		$display("");
				
		// write driver
		mst_agent.AXI4LITE_WRITE_BURST(
			addr,
			prot,
			data_wr,
			resp
		);
		
		#20;
		mst_agent.AXI4LITE_WRITE_BURST(
			addr2,
			prot,
			data_wr2,
			resp
		);
		
		
		$display("[%0t] WRITE_1 complete | addr=0x%08h data=0x%08h resp=%0d", $time, addr, data_wr, resp);
		$display("[%0t] WRITE_2 complete | addr=0x%08h data=0x%08h resp=%0d", $time, addr2, data_wr2, resp);
		
		#50;
		
		// read driver
		mst_agent.AXI4LITE_READ_BURST(
			addr,
			prot,
			data_rd,
			resp
		);
		
		#20;
		mst_agent.AXI4LITE_READ_BURST(
			addr2,
			prot,
			data_rd2,
			resp
		);
		
		
		$display("[%0t] READ complete | addr=0x%08h data=0x%08h resp=%0d", $time, addr, data_rd, resp);
		$display("[%0t] READ_2 complete | addr=0x%08h data=0x%08h resp=%0d", $time, addr2, data_rd2, resp);
		
		// check result
//		if ((data_rd == data_wr) && (data_rd2 == data_wr2))
//			$display("[%0t] [PASS] read data matches write data (0x%08h) & (0x%0h)", $time, data_rd, data_rd2);
//		else
//			$display("[%0t] [FAIL]");

		if ((data_rd == data_wr) && (data_rd2 == data_wr2)) begin
		    $display("");
		    $display("################################################################");
			$display("#              >>>  ALL TESTS PASSED  <<<                   ");
		end else begin
			$display("#              >>>  SOME TESTS FAILED  <<<                  ");
		end
		$display("################################################################");
		$display("");
		
		#200;
		$finish;
	end
endmodule
