//-----------------------RTL-----------------------------//

module counter(clk, rst, load, mode, data_in, data_out);
	input clk, rst, load, mode;
	input [3:0] data_in;
	output reg [3:0] data_out;
	
	always @(posedge clk)
	begin
		if(rst)	data_out <= 4'd0;
		
		else if(load) data_out <= data_in;
		
		else if (mode) 
		begin
			if(data_out == 4'd11)	data_out <= 4'd0;
			else data_out <= data_out + 1;
		end
			
		else 
		begin 
			if(data_out == 4'd0)	data_out <= 4'd11;
			else data_out <= data_out - 1;
		end
	end
endmodule


//--------------------------INTERFACE--------------------//

interface counter_if(input bit clk);
	logic rst, load, mode;
	logic [3:0] data_in, data_out;
	
	clocking wr_dr_cb @(posedge clk);
		default input #1 output #1;
		output rst;
		output load;
		output mode;
		output data_in;
	endclocking: wr_dr_cb
	
	clocking wr_mon_cb @(posedge clk);
		default input #1 output #1;
		input rst;
		input load;
		input mode;
		input data_in;
	endclocking: wr_mon_cb
	
	clocking rd_mon_cb @(posedge clk);
		default input #1 output #1;
		input data_out;
	endclocking: rd_mon_cb
	
	modport WR_DR_MOD  (clocking wr_dr_cb);
	modport WR_MON_MOD (clocking wr_mon_cb);
	modport RD_MON_MOD (clocking rd_mon_cb);
	
endinterface: counter_if

//---------------------TRANSXACTION CLASS----------------//

class counter_transxaction;
	rand bit rst, mode, load;
	rand bit [3:0] data_in;
	logic [3:0] data_out;
	
	constraint RST_PROB {rst dist{0:=10, 1:=3} ;}
	constraint MODE_PROB {mode dist{0:=5, 1:=5} ;}
	constraint LOAD_PROB {load dist{0:=5, 1:=5} ;}
	constraint DATA_INSIDE {data_in inside {[1:10]};}
	
	static int trans_ID;
	//int total_no_of_tranxaction	= 20;
	
	function void display(input string str);
		$display("=====================================");
		$display("\n Inside String msg : %0s", str);
		$display($time,"Tranzxaction ID = %0d", trans_ID, "\nrst = %0d", rst, "\nload =%0d", load, "\nmode =%0d", mode, "\ndata_in = %0d", data_in, "\ndata_out = %0d",data_out);
		$display("=====================================");
	endfunction: display
	
	function void post_randomize();
		trans_ID++;
		//display("RANDOM-DATA");
	endfunction: post_randomize
endclass

//------------------------------------------------------------------------------------

class counter_gen;
	counter_transxaction 			gen_oftrans_h;
	counter_transxaction 			gen2wr_oftrans_h;
	
	mailbox #(counter_transxaction) gen2wr_box;
	
	function new(mailbox #(counter_transxaction) gen2wr_box);
		this.gen2wr_box = gen2wr_box;
		this.gen_oftrans_h = new();
	endfunction: new
	
	virtual task start;
	fork
		for(int i=0; i<20; i++)		//repeat(gen_oftrans_h.total_no_of_tranxaction) 
		begin
			assert(gen_oftrans_h.randomize);
			gen2wr_oftrans_h = new gen_oftrans_h;
			
			//gen_oftrans_h.display("SEE THE RANDOM DATA");
					
			gen2wr_box.put(gen2wr_oftrans_h);
			
		end
	join_none
	endtask: start
endclass: counter_gen

//---------------------------WRITE DRV-----------------------------------------------------

class counter_write_drv;
	
	counter_transxaction 			write_drv_oftrans_h;

	virtual counter_if.WR_DR_MOD 	wr_dr_MOD_if_h;
	
	mailbox #(counter_transxaction) gen2wr_box;
	
	function new (mailbox #(counter_transxaction) 	gen2wr_box, 
					virtual counter_if.WR_DR_MOD 	wr_dr_MOD_if_h);
		this.gen2wr_box  = gen2wr_box;
		this.wr_dr_MOD_if_h = wr_dr_MOD_if_h;
	endfunction: new
	
	virtual task drive;
		@(wr_dr_MOD_if_h.wr_dr_cb)
		begin
			wr_dr_MOD_if_h.wr_dr_cb.rst 	<= write_drv_oftrans_h.rst;
			wr_dr_MOD_if_h.wr_dr_cb.load 	<= write_drv_oftrans_h.load;
			wr_dr_MOD_if_h.wr_dr_cb.mode 	<= write_drv_oftrans_h.mode;
			wr_dr_MOD_if_h.wr_dr_cb.data_in <= write_drv_oftrans_h.data_in;
		end
	endtask: drive
	
	virtual task start;
	fork
		for(int i=0; i<20; i++)/* repeat(20) */ //repeat(write_drv_oftrans_h.total_no_of_tranxaction) 
		begin
			gen2wr_box.get(write_drv_oftrans_h);
			//write_drv_oftrans_h.display("Got the RAND DATA FROM WRITE DRV");
			drive();
			//$display("DRIVING COMPLETED TO DUT");
		end
	join_none
	endtask: start
	
endclass

//----------------------------WRITE MON------------------------

class counter_write_mon;
	
	counter_transxaction 			 write_mon_oftrans_h;
	counter_transxaction 			 scopy_write_mon_oftrans_h;
	
	virtual counter_if.WR_MON_MOD	 wr_mon_MOD_if_h;
	
	mailbox #(counter_transxaction)  wr2rfm_box_l;
	
	function new (virtual counter_if.WR_MON_MOD	   wr_mon_MOD_if_h, 
				  mailbox #(counter_transxaction)  wr2rfm_box_l);
		this.wr_mon_MOD_if_h 	= wr_mon_MOD_if_h;
		this.wr2rfm_box_l       = wr2rfm_box_l;
		write_mon_oftrans_h = new;
	endfunction:new
	
	virtual task sample_wr;
		@(wr_mon_MOD_if_h.wr_mon_cb)
		begin
			write_mon_oftrans_h.rst 	= wr_mon_MOD_if_h.wr_mon_cb.rst;	
	        write_mon_oftrans_h.load 	= wr_mon_MOD_if_h.wr_mon_cb.load;	
	        write_mon_oftrans_h.mode 	= wr_mon_MOD_if_h.wr_mon_cb.mode;
		    write_mon_oftrans_h.data_in = wr_mon_MOD_if_h.wr_mon_cb.data_in;
		end
		endtask: sample_wr
		
	virtual task start;
		fork
			forever
			begin
				sample_wr();
				//write_mon_oftrans_h.display("Write monitor works perfectly");
				scopy_write_mon_oftrans_h = new write_mon_oftrans_h;
				wr2rfm_box_l.put(scopy_write_mon_oftrans_h);
				//scopy_write_mon_oftrans_h.display("Write Moniter");
			end
		join_none
	endtask: start

endclass: counter_write_mon

//-------------------------------------------------Read Moniter-----------------------

class counter_read_moniter;

	virtual counter_if.RD_MON_MOD		rd_mon_MOD_if_h;
	
	counter_transxaction				read_mon_oftrans_h;
	counter_transxaction				scopy_read_mon_oftrans_h;
		
	mailbox #(counter_transxaction)		rd2sb_box;
	
	function new (virtual counter_if.RD_MON_MOD		rd_mon_MOD_if_h,
				  mailbox #(counter_transxaction)   rd2sb_box);
				  
		this.rd_mon_MOD_if_h = rd_mon_MOD_if_h;
		this.rd2sb_box 		 = rd2sb_box;
		
		read_mon_oftrans_h   = new;
	endfunction: new
	
	virtual task sample_rd;
		@(rd_mon_MOD_if_h.rd_mon_cb)
			begin
				read_mon_oftrans_h.data_out = rd_mon_MOD_if_h.rd_mon_cb.data_out;
				//$display("Data_Out from Read Moniter");
			end
	endtask: sample_rd
	
	virtual task start;
		fork
			forever
				begin
					sample_rd();
					scopy_read_mon_oftrans_h = new read_mon_oftrans_h;
					rd2sb_box.put(scopy_read_mon_oftrans_h);
					//scopy_read_mon_oftrans_h.display("RD Moniter");
					
				end
		join_none
	endtask: start
	
endclass: counter_read_moniter

//---------------------------------------------------------------------

class counter_refrence_model;

	counter_transxaction			rm_oftrans_h;
	counter_transxaction			rm_oftrans_h_temp;
	
	mailbox #(counter_transxaction) wr2rfm_box_l;
	mailbox #(counter_transxaction) rfm2sb_box_l;
	
	function new (mailbox #(counter_transxaction) wr2rfm_box_l,
				  mailbox #(counter_transxaction) rfm2sb_box_l);
		this.wr2rfm_box_l = wr2rfm_box_l;
		this.rfm2sb_box_l = rfm2sb_box_l;
	endfunction: new
	
	task fAkE_counter();
		begin
			if(rm_oftrans_h.rst) /*then*/	
				rm_oftrans_h.data_out = 4'd0;
			else if(rm_oftrans_h.load) 		
				rm_oftrans_h.data_out = rm_oftrans_h.data_in;
			
			else if(rm_oftrans_h.mode)
				begin
					if(rm_oftrans_h.data_out == 4'd11)		
						rm_oftrans_h.data_out = 4'd0;
					else									
						rm_oftrans_h.data_out = rm_oftrans_h.data_out + 1;
				end
			
			else
				begin
					if(rm_oftrans_h.data_out == 4'd0)		
						rm_oftrans_h.data_out = 4'd11;
					else									
						rm_oftrans_h.data_out = rm_oftrans_h.data_out - 1;
				end
		end
	endtask: fAkE_counter
	
	virtual task start;
		fork
			forever
				begin
					
					wr2rfm_box_l.get(rm_oftrans_h);
					//rm_oftrans_h_temp = new rm_oftrans_h;
					fAkE_counter();
					
					rfm2sb_box_l.put(rm_oftrans_h);
					//rm_oftrans_h.display("HEEE");		// Till here it is working perfectly ok.
				end
		join_none
	endtask: start
	
endclass: counter_refrence_model

//------------------------------------------------------------------

class counter_scoreboard;

	event DONE;
	
	counter_transxaction			rfm2sb_oftrans_h;
	counter_transxaction			rm2sb_oftrans_h;
	
	//counter_transxaction			coverage_data;
	
	mailbox #(counter_transxaction) rfm2sb_box;
	mailbox #(counter_transxaction) rm2sb_box;
	
	int data_verified = 0;
	
	function new (mailbox #(counter_transxaction) rfm2sb_box,
				  mailbox #(counter_transxaction) rm2sb_box);
		this.rfm2sb_box = rfm2sb_box;
		this.rm2sb_box  = rm2sb_box;
		
		//coverage = new;
	endfunction: new
	
	// Coverage Code
	/* covergroup coverage;
		RST   : coverpoint coverage_data.rst;
		MODE  : coverpoint coverage_data.mode;
		LOAD  : coverpoint coverage_data.load;
		DATA_IN : coverpoint coverage_data.data_in {bins a = {[1:10]};}
		CR : cross RST, MODE, LOAD, DATA_IN;
	endgroup: coverage */

	virtual task check();
		if (rm2sb_oftrans_h.data_out == rfm2sb_oftrans_h.data_out)
			rm2sb_oftrans_h.display("Data Verified");
			
		else
			rm2sb_oftrans_h.display("Data Mismatch");
		
		// Shallow Copy rm_data to cov_data
		/* coverage_data = new rm2sb_oftrans_h;
		coverage.sample(); */
		data_verified++;
		$display("data_verified = %0d",data_verified);
		if (data_verified == 20/* rfm2sb_oftrans_h.total_no_of_tranxaction */)
		begin
			->DONE;
		end
	endtask : check

	
	task start;
		fork 
			forever
				begin
					rfm2sb_box.get(rfm2sb_oftrans_h);
					rm2sb_box.get(rm2sb_oftrans_h);
					
					//rfm2sb_oftrans_h.display("OIOIOIOI");
					rfm2sb_oftrans_h.display("aaaaaaaaaaahhheeeellllpppp");
					check();
					
					//coverage.sample();
				end
		join_none
	endtask: start
	
	
	
	
	function void report();
	$display("XXXXXXXXXXXXX-SCOREBOARD-REPORT-XXXXXXXXXXXXXXXXX");
	$display("\n Data_Verified :%0d", data_verified);
	$display("XXXXXXXXXXXXX-SCOREBOARD-REPORT-XXXXXXXXXXXXXXXXX");
	endfunction: report
	
endclass: counter_scoreboard



//--------------------------------------------------ENVIRONMENT CLASS-----------------------------------------

class counter_environment;

	virtual counter_if.WR_DR_MOD		env_wrdr_MOD_vif_h;
	virtual counter_if.WR_MON_MOD		env_wrmon_MOD_vif_h;
	virtual counter_if.RD_MON_MOD		env_rdmon_MOD_vif_h;
	
	mailbox #(counter_transxaction)		gen2wr_box = new(); 
	mailbox #(counter_transxaction)		wr2rfm_box = new(); 
	mailbox #(counter_transxaction)		rm2sb_box = new(); 
	mailbox #(counter_transxaction)		rfm2sb_box = new(); 
	
	counter_gen		env_gen_h;
	counter_write_drv	env_wrdrv_h;
	counter_write_mon	env_wrmon_h;
	counter_read_moniter	env_rdmon_h;
	counter_refrence_model	env_rfm_h;
	counter_scoreboard	env_sb_h;
	
	function new (virtual counter_if.WR_DR_MOD env_wrdr_MOD_vif_h,
				  virtual counter_if.WR_MON_MOD	env_wrmon_MOD_vif_h,
				  virtual counter_if.RD_MON_MOD	env_rdmon_MOD_vif_h);
				  
		this.env_wrdr_MOD_vif_h = env_wrdr_MOD_vif_h;
		this.env_wrmon_MOD_vif_h = env_wrmon_MOD_vif_h;
		this.env_rdmon_MOD_vif_h = env_rdmon_MOD_vif_h;
	endfunction: new
	
	virtual task build;
		env_gen_h		=  new(gen2wr_box);
		env_wrdrv_h		=  new(gen2wr_box, env_wrdr_MOD_vif_h);
	        env_wrmon_h		=  new(env_wrmon_MOD_vif_h, wr2rfm_box);
                env_rdmon_h		=  new(env_rdmon_MOD_vif_h, rm2sb_box);
	        env_rfm_h		=  new(wr2rfm_box,rfm2sb_box);
                env_sb_h		=  new(rfm2sb_box,rm2sb_box);
	endtask: build
	
	task all_start;
		env_gen_h.start();
		env_wrdrv_h.start();
		env_wrmon_h.start();
		env_rdmon_h.start();
		env_rfm_h.start();
		env_sb_h.start();
	endtask: all_start
	
	task all_stop;
		wait(env_sb_h.DONE.triggered);
	endtask:all_stop
	
	task run;
		all_start();
		all_stop();
		env_sb_h.report();
	endtask: run
endclass: counter_environment

//---------------------------------------TEST CASE---------------------------------------------------
	
class counter_test_bc;
	virtual counter_if.WR_DR_MOD	test_wrdr_MOD_if_h;
	virtual counter_if.WR_MON_MOD	test_wrmon_MOD_if_h;
	virtual counter_if.RD_MON_MOD	test_rdmon_MOD_if_h;
	
	counter_environment	env_h;
	
	function new (virtual counter_if.WR_DR_MOD	test_wrdr_MOD_if_h,
				  virtual counter_if.WR_MON_MOD	test_wrmon_MOD_if_h,
				  virtual counter_if.RD_MON_MOD	test_rdmon_MOD_if_h);
		this.test_wrdr_MOD_if_h	 = test_wrdr_MOD_if_h;
		this.test_wrmon_MOD_if_h = test_wrmon_MOD_if_h;
        	this.test_rdmon_MOD_if_h = test_rdmon_MOD_if_h;
		
		env_h = new(test_wrdr_MOD_if_h, test_wrmon_MOD_if_h, test_rdmon_MOD_if_h);
		
	endfunction: new
	
	task build_n_run;
		env_h.build();
		env_h.run();
		endtask: build_n_run
endclass: counter_test_bc

//---------------------------------------TOP module------------------------------------------------

module counter_top;
	parameter cycle = 10;
	bit clk;
	int total_no_of_tranxaction = 1;
	
	
	counter_if 			DUT_IF(clk);
	
	counter_test_bc 	test_h;
	
	//connecting Interface to DUV
	
	counter MOD12 (.clk(clk), 
				   .rst(DUT_IF.rst),
				   .mode(DUT_IF.mode),
				   .load(DUT_IF.load),
				   .data_in(DUT_IF.data_in),
				   .data_out(DUT_IF.data_out));
				   
	initial
		begin
			test_h = new(DUT_IF, DUT_IF, DUT_IF);
			
			total_no_of_tranxaction = 20;
			
			test_h.build_n_run();
			
				$finish;

		end
	
	initial
		begin
			clk = 1'b0;
			forever		#(cycle/2)	clk = ~clk;
		end
endmodule: counter_top