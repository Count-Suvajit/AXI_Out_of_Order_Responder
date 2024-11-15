module rtl();
  
  int idx;
  
  bit [31:0] wdata_l[1024][bit [1:0]];
  bit wdata_l_valid[bit [1:0]];
  
  always @(posedge clk) begin
    
    if(awvalid && awready) begin
      awaddr_q.push_back(awaddr);
      awid_q.push_back(awid);
      awlen_q.push_back(awlen);
      awsize_q.push_back(awsize);
      awburst_q.push_back(awburst);
    end
    
  end
 
  always @(posedge clk) begin
    
    if(wvalid && wready) begin
      
      wdata_l_valid[wid]=0;
      
      wdata_l[widx][wid] = awdata;
      widx+=1;
      
      if(wlast==1) begin
        widx=0;
        wdata_l_valid[wid] = 1;
      end
      
    end
    
  end  
  
  always @(posedge clk) begin
    
    if(addr_q.size>5 || (addr_q.size>0 && wait_cnt==100)) begin
      
      idx = $urandom_range(addr_q.size-1,0);
      awaddr_r = awaddr_q[idx];
      awid_r = awid_q[idx];
      awlen_r = awlen_q[idx];
      awsize_r = awsize_q[idx];
      awburst_r = awtrans_q[idx];
      awaddr_q.delete(idx);
      awid_q.delete(idx);
      awlen_q.delete(idx);
      awsize_q.delete(idx);
      awburst_q.delete(idx);
      wait_cnt = 0;
      write_q.push_back(awid_r,awsize_r,awburst_r,awlen_r,awaddr_r);
    end
    else if(addr_q.size > 0) begin
      wait_cnt+=1;
    end
    
  end
  
  always @(posedge clk) begin
    
    if(write_q.size>0 && wdata_l_valid[wdata_q[0][awid_sidx:awid_eidx]]==1) begin
      
      awaddr_rr = write_q[0][awaddr_sidx:awaddr_eidx];
      awlen_rr = write_q[0][awlen_sidx:awlen_eidx];
      awburst_rr = write_q[0][awburst_sidx:awburst_eidx];
      awsize_rr = write_q[0][awsize_sidx:awsize_eidx];
      awid_rr = write_q[0][awid_sidx:awid_eidx];
      
      resp = check_addr(awaddr_rr,awburst_rr,awsize_rr,awlen_rr);
      
      if(resp==0) begin
        for(int i=0; i<awlen_rr; i+=1) begin
        
          awaddr_rrr = get_next_addr(awaddr_rr,awburst_rr,awsize_rr,awlen_rr,i);
          start_byte_lane = awaddr_rrr%(data_bus_bytes);
          end_byte_lane = start_byte_lane + (1<<awsize_rr) >= data_bus_bytes ? data_bus_bytes - 1 : start_byte_lane + (1<<awsize_rr);
            for(j=start_byte_lane;j<end_byte_lane;j++) begin
              mem[awaddr_rrr+j-start_byte_lane] = wdata_l[i][awid_rr][(1+j)*8-:8];
            end
        end
      end

      bresp_q.push_back(awid_rr,resp);   
      
      write_q=write_q[1:$];
  
    end
    
  end
  
  always @(posedge clk) begin
    
    if(!in_progress && bresp_q.size > 0) begin
      
      in_progress = 1;
      bvalid = 1;
      bresp = bresp_q[0][bresp_sidx:bresp_eidx];
      bid = bresp_q[0][bid_sidx:bid_eidx];
      bresp_q = bresp_q[1:$];
      
    end
    else if(in_progress==1 && bready==1) begin
      
      bvalid = 0;
      in_progress = 0;
      
    end
    
  end
  
  function automatic bit [31:0] get_next_addr(addr,burst,size,len,i);
    
    aligned_addr = (int'(addr/size))*size;
    dlen = size*len;
    wrap_boundary = aligned_addr + dlen;
    
    next_addr = i == 0 ? addr : aligned_addr + size*i; // Except 1st transfer all other transfers are aligned.
    if(burst == FIXED)
      next_addr = addr;
    else if(burst == WRAP && i>0)
      next_addr = next_addr%dlen;
    
    return next_addr;
    
  endtask
  
endmodule
