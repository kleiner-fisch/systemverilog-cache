
interface cache_if;
    // output from dut
    logic [7:0] key, update_value;
    logic match_found;
    // input to dut
    logic [7:0] read_value;
    logic find, update, reset, clk;

  modport DRV(output match_found, read_value,
        input update, reset, clk, find, key, update_value);
  
    modport MON( input match_found, read_value,
        output update, reset, clk, find, key, update_value);
endinterface

typedef bit golden_model_t[bit [127:0]];

/**
*
*
*/

class transaction;
  // input to dut
  rand bit find, update;
  rand bit [7:0] key, update_value;
  // output from dut
  bit match_found;
  bit [7:0] read_value;

  /*
  constraint ctrl_find {
      find dist{ 0:=30, 1:=70};
  }

  // TODO constrain that update should be 1 more often than find
  constraint ctrl_update {
      update dist{ 0:=30, 1:=70};
  }*/

  constraint size_constraint { key < 4; update_value < 16;}

  
  constraint find_update { find != update;}
  

  function void display();
      $display("find: %0d \t update: %0d \t key: %0d \t upvalue: %0d", find, update, key, update_value);
      $display("match_found: %0d \t value: %0d", match_found, read_value);
  endfunction
  
  function transaction copy();
    copy = new();
    copy.find = this.find;
    copy.update = this.update;
    copy.key = this.key;
    copy.update_value = this.update_value;
    copy.match_found = this.match_found;
    copy.read_value = this.read_value;
  endfunction

endclass


/**
*
*
*/


class generator;

    transaction trans;
    mailbox #(transaction) mbx;
  
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    trans = new();    
  endfunction 

    task run();
      for(int i = 0; i < 100; i++) begin
        /*assert (trans.randomize()) else $display("Randomization failed");*/
        if(i<11) begin
          trans.update = 1;
          trans.find = 0;
        end else begin
            trans.find = i%2;         	
        	trans.update = 1- trans.find;
        end

		trans.key = i%4;
        trans.update_value = i%16;        
        $display("[GEN] : DATA SENT TO DRIVER");
        trans.display();
        mbx.put(trans.copy());
      end
    endtask
endclass


/**
*
*
*/

class driver;
    virtual cache_if.DRV cif;
    mailbox #(transaction) mbx;
  	transaction data;

  function new(mailbox #(transaction) mbx);
        this.mbx = mbx; 
    endfunction
    
    task run();
    forever begin
      mbx.get(data);
      @(posedge cif.clk);
      cif.find = data.find;
      cif.update = data.update;
      cif.key = data.key;
      cif.update_value = data.update_value;
      $display("[DRV] Interface Trigger");
      data.display(); 
      
      @(negedge cif.clk);
    end
    endtask
endclass






class monitor;
	mailbox #(transaction) mbx;
	transaction trans;
      virtual cache_if.MON cif;
  

	 
  function new (mailbox #(transaction) mbx);
	 	this.mbx = mbx;
	 endfunction

	task run();
		trans = new();
		forever begin
			@(negedge cif.clk)
            trans.match_found <= cif.match_found;
			trans.read_value <= cif.read_value;
          	// wait one full CLOCK_CYCLE_TIME
			//# 4;
          @(posedge cif.clk);
          	trans.find <= cif.find;
            trans.update <= cif.update;
            trans.key <= cif.key;
            trans.update_value <= cif.update_value;
          	mbx.put(trans.copy());
			$display("[MON] DATA SENT TO SCOREBOARD");
			trans.display();
		end
	endtask

endclass


class scoreboard;
	transaction trans;
	 mailbox #(transaction) mbx;
  // These queues contain the keys and values in the cache
  bit[7:0] keys [$];
  bit[7:0] values [$];
  
  function new (mailbox #(transaction) mbx);
	 	this.mbx = mbx;    
    initQueues();
	endfunction
  
  function initQueues();
    for(int i=0;i<8;i++) begin
      keys = {keys, 8'bx};
      values = {values, 8'bx};
    end
  endfunction

  
  function processTransaction(transaction trans);
    if(trans.find) begin
      int indexResult[$] = this.keys.find_last_index with (item == trans.key);
      int keyFound = indexResult.size();
      int keyFoundCorrectly = keyFound == trans.match_found;
      assert(keyFoundCorrectly) begin
      end else begin
        $display("==================== ASSERTION ERROR ==================: time: %t", $time);
        $display("model.match_found: %b", keyFound);
        $display("keys: %p", keys);
        $display("values: %p", values);
        // The match found check below only makes sense if the key was found as expected
        return 1;
      end
    end
    if(trans.match_found) begin
      // Since we reached here, we already established that the key exists. Hence, the access below is save
      int indexResult2[$] = this.keys.find_last_index with (item == trans.key);
      int index = indexResult2[0];
      int value = values[index];
      assert(value == trans.read_value) begin
      end else begin
        $display("==================== ASSERTION ERROR ==================: time: %t", $time);
        $display("cache.index: %d, cache.value: %d", index, value);
        $display("keys: %p", keys);
        $display("values: %p", values);
      end
    end
    if(trans.update) begin
      this.keys.pop_front();
      this.values.pop_front();
      this.keys.push_back(trans.key);
      this.values.push_back(trans.update_value);
    end
    return 0;
  endfunction
  
	task run();
		trans = new();
		forever begin
			mbx.get(trans);
            $display("[SCO] DATA RECEIVED FROM MONITOR");
			trans.display();
          	processTransaction(trans);
		end
	endtask
endclass






`timescale 1 ns/100ps
module cache_tb ;
	bit clk;
    cache_if cif();
	driver drv;
	mailbox #(transaction) gen2drv;
  	generator gen;
  
    monitor mon;
  	scoreboard sco;
  	mailbox #(transaction) mon2sco;
  
	cache cache_1(.clk(cif.clk), .reset(cif.reset), .find(cif.find), .key(cif.key), .match_found(cif.match_found), .read_value(cif.read_value),
			.update(cif.update), .update_value(cif.update_value)
			);

	initial begin
		cif.reset <= 1;
        cif.clk <= 0;
		#2;
		cif.reset <= 0;
      
      	gen2drv = new();
      drv = new(gen2drv);
		drv.cif = cif;
      	gen = new(gen2drv);
      	
        mon2sco = new();
      mon = new(mon2sco);
		mon.cif = cif;
      	sco = new(mon2sco);
	end

	always @(cif.clk) begin 
      // value of CLOCK_CYCLE_TIME is 2
		#2 cif.clk <= ~cif.clk;
	end
  
  
  	initial begin
      /*for(int i=0;i<20;i++) begin
        @(posedge cif.clk)
        cif.update_value = $urandom_range(0, 127);
        cif.key = $urandom_range(0, 127);
        cif.find = $urandom_range(0, 1);
		cif.update = 1- cif.find ;
      end*/
      $dumpfile("dump.vcd");
  	  $dumpvars;
      # 400;
      $finish;
    end

	initial begin
      #10;
	fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join
     // wait(gen_done.triggered);
	//	$finish;
	end

endmodule 
