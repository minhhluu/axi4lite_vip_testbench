`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Minh Luu
// 
// Create Date: 02/27/2026 05:40:00 PM
// Design Name: 
// Module Name: tb_axi4_lite_intermediate
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*; // master
import design_1_axi_vip_1_0_pkg::*; // slave
import design_1_axi_vip_0_1_pkg::*; // passthrough

module tb_axi4_lite_intermediate();

	bit aclk = 0;
	bit aresetn = 1;
	
	// 100MHz clock
	always #5ns aclk <= ~aclk;
	
	// declare agent
	design_1_axi_vip_0_0_mst_t        mst_agent;
	design_1_axi_vip_1_0_slv_mem_t    slv_mem_agent;
	design_1_axi_vip_0_1_passthrough_t passthrough_agent;
	
	design_1_wrapper DUT(
		.aclk(aclk),
		.aresetn(aresetn)
	);
	
	// declare testbench signals
	xil_axi_resp_t   	resp;
	xil_axi_prot_t   	prot;
	xil_axi_ulong  	 	base_addr = 32'h0000_1000;
	xil_axi_burst_t		XIL_AXI_BURST_TYPE_INCR=2'b01,
	                    XIL_AXI_BURST_TYPE_WRAP=2'b10; // burst type WRAP
	xil_axi_size_t		XIL_AXI_SIZE_4BYTE    = 3'b010; // size
	xil_axi_len_t		len=3;
	xil_axi_uint		id=0;	
	axi_transaction		incr_wr_tx, 
	                    wrap_wr_tx, 
	                    incr_tx_temp;

	bit [31:0]          beat0 = 32'hAAAA_0001, 
	                    beat1 = 32'hBBBB_0002, 
	                    beat2 = 32'hCCCC_0003,
	                    beat3 = 32'hDDDD_0004;
    logic [31:0]        new_addr [0:3];   // all 4 beat addresses
    logic [31:0]        wrap_boundary;
    	
	task monitor_transaction();
		forever begin
			@(posedge aclk);
			// write address channel
			$display("[%0t] AW: VALID=%0b READY=%0b | W: VALID=%0b READY=%0b | B: VALID=%0b READY=%0b",
				$time,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.AWVALID,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.AWREADY,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.WVALID,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.WREADY,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.BVALID,
				DUT.design_1_i.axi_vip_passthrough.inst.IF.BREADY
			);
		end
	endtask
	
	task check_handshake();
	   forever begin
	       @(posedge aclk);	       
	       // write address channel (AWVALID & AWREADY)
	       if (DUT.design_1_i.axi_vip_slave.inst.IF.AWVALID &&
	           DUT.design_1_i.axi_vip_slave.inst.IF.AWREADY) begin
	           $display("[%0t] write address is valid & ready", $time);
	       end
	       // write data channel (WVALID & WREADY)
	       if (DUT.design_1_i.axi_vip_slave.inst.IF.WVALID &&
	           DUT.design_1_i.axi_vip_slave.inst.IF.WREADY) begin
	           $display("[%0t] write data is valid & ready", $time);
	       end
	       // write response channel (BVALID & BREADY)
	       if (DUT.design_1_i.axi_vip_slave.inst.IF.BVALID &&
	           DUT.design_1_i.axi_vip_slave.inst.IF.BREADY) begin
	           $display("[%0t] write response is valid & ready", $time);
	       end
	   end
	endtask

	task test_incr_wr();
	    int i;
	    logic [31:0] addr_beat;         // current beat address
		incr_wr_tx = mst_agent.wr_driver.create_transaction("incr_wr");
		
		incr_wr_tx.set_write_cmd(
			base_addr,
			XIL_AXI_BURST_TYPE_INCR,
			id,
			len, // len + 1 = beats
			XIL_AXI_SIZE_4BYTE
		);
		incr_wr_tx.set_data_beat(0, beat0);
		incr_wr_tx.set_data_beat(1, beat1);
		incr_wr_tx.set_data_beat(2, beat2);
		incr_wr_tx.set_data_beat(3, beat3);
		
		
		// beat's address: base_addr + i * (2 ^ size)
		// size = 2 (4 bytes), stride = 4
		
		for (i = 0; i <= len; i++) begin
			addr_beat     = base_addr + i * (1 << XIL_AXI_SIZE_4BYTE);
			new_addr[i] = addr_beat;
			$display("[%0t] Beat[%0d] new_addr=0x%08h data_beat=0x%08h | base_addr=0x%08h",
				$time, i, addr_beat, incr_wr_tx.get_data_beat(i), base_addr);
			@(posedge aclk);
		end
		
		mst_agent.wr_driver.send(incr_wr_tx);
		$display("[%0t] INCR write done", $time);
	endtask

	task test_wrap_wr();
		incr_tx_temp = mst_agent.wr_driver.create_transaction("wrap_wr");
		incr_tx_temp.set_write_cmd(
			base_addr,
			XIL_AXI_BURST_TYPE_INCR,
			id,
			len,               // len=3 -> 4 beats (valid for WRAP)
			XIL_AXI_SIZE_4BYTE
		);
		incr_tx_temp.set_data_beat(0, beat0);
		incr_tx_temp.set_data_beat(1, beat1);
		incr_tx_temp.set_data_beat(2, beat2);
		incr_tx_temp.set_data_beat(3, beat3);
		
		// convert INCR -> WRAP
		// wrap_offset = 8 means WRAP starts at base_addr+8 (0x1008)
		@(posedge aclk) wrap_wr_tx = incr_tx_temp.convert_incr_to_wrap(11'd8);
		$display("[%0t] Converted INCR to WRAP burst (wrap_offset=8)", $time);
		
        // set boundary
        wrap_boundary = base_addr + (len+1) * (1 << XIL_AXI_SIZE_4BYTE);
		@(posedge aclk) $display("[%0t] Boundary = 0x%08h  (0x%08h + %0d beats x %0d bytes)",
			$time,
			wrap_boundary,
			base_addr, len+1, (1 << XIL_AXI_SIZE_4BYTE));
		
		@(posedge aclk) mst_agent.wr_driver.send(wrap_wr_tx);
		$display("[%0t] WRAP write done", $time);
		$display("===============================");
	endtask

	initial begin
		// Agent setup
		mst_agent = new("master vip agent", DUT.design_1_i.axi_vip_master.inst.IF);
		slv_mem_agent = new("slave mem vip agent", DUT.design_1_i.axi_vip_slave.inst.IF);
		passthrough_agent = new("passthrough vip agent", DUT.design_1_i.axi_vip_passthrough.inst.IF);
		
		mst_agent.set_agent_tag("master vip");
		// mst_agent.set_verbosity(400);
		
		slv_mem_agent.set_agent_tag("slave mem vip");
		// slv_mem_agent.set_verbosity(400);
		
		passthrough_agent.set_agent_tag("pass agent vip");
		// passthrough_agent.set_verbosity(400);
		
		mst_agent.start_master();
		slv_mem_agent.start_slave();
		DUT.design_1_i.axi_vip_passthrough.inst.set_passthrough_mode();
		
		// reset sequence
		aresetn = 1;
		#20;
		aresetn = 0;
		#20;
		aresetn = 1;
		#20;
		
		// test INCR burst write
		$display("====== incr burst write ======");
		fork
			test_incr_wr();
			// check_handshake();
			// monitor_transaction();
		join_any
		// disable fork;
		
		repeat(5) @(posedge aclk);
		
		// test WRAP burst write
		$display("====== wrap burst write ======");
		fork
			test_wrap_wr();
			// check_handshake();
		join_any
		
		
		#200;
		$finish;
	end

endmodule
