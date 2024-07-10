// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
module trenc_atb_data
  import trenc_pkg::*;
( 
   //ATB interface 
   //global signal 
   input  logic                        trenc_gclk_i          ,  
   input  logic                        trenc_rstn_i          ,   
   //data signal 
   output logic[$clog2(ATBWIDTH)-4:0]  trenc_atbyte_o        ,
   output logic[ATBWIDTH-1:0]          trenc_atdata_o        , 
   output logic[6:0]                   trenc_atid_o          ,  
   input  logic                        trenc_atready_i       ,
   output logic                        trenc_atvalid_o       ,
   //flush control signal 
   input  logic                        trenc_afvalid_i       ,
   output logic                        trenc_afready_o       ,
   //data_in signal  
   input  logic[POP_WIDTH-1:0]         trenc_bufdat_i        ,
   output logic                        trenc_bufreq_o        ,
   input  logic[1:0]                   trenc_core_id_i       ,
   input  logic                        trenc_bufvld_i        ,
   input  logic                        trenc_buffull_i       ,  
   input  logic                        trenc_bufempty_i      ,
   input  logic[$clog2(DEPTH)-1:0]     trenc_wrptr_i         ,
   input  logic[$clog2(DEPTH)-1:0]     trenc_rdptr_i         
   );
   

  logic [2:0]   atbytes;
  logic [POP_WIDTH-1:0] pkt_dat;
  //logic [POP_WIDTH-1:0] inmouth_dat;
  logic [ATBWIDTH-1:0]  inmouth_dat;
  logic [PKTDATA_WIDTH-1:0] pkt_len;
  logic [1:0] cnt_load,cnt;
  logic buf_req;


  always_comb begin
    pkt_len ={PKTDATA_WIDTH{1'b0}};
    pkt_dat ={POP_WIDTH{1'b0}};
    if(trenc_bufvld_i) begin
      pkt_len = trenc_bufdat_i[PKTDATA_WIDTH-1:0];
      pkt_dat = trenc_bufdat_i[POP_WIDTH-1:PKTDATA_WIDTH];
    end 
  end

 
  always_comb begin
    if(pkt_len>0 && pkt_len<=64)  cnt_load =2'b00;
    else if(pkt_len>65  && pkt_len<=128) cnt_load = 2'b01;
    else if(pkt_len>129 && pkt_len<=192) cnt_load = 2'b10;
    else cnt_load = 2'b00;
  end 
 
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i)begin
      cnt<='b0;
    end else if(cnt == cnt_load && trenc_atready_i && trenc_bufvld_i) begin
      cnt<='b0;
    end else if(trenc_atready_i && trenc_bufvld_i) begin
      cnt<=cnt+1'b1;
    end
  end

  // need change logic

  always_comb begin
      buf_req ='b0;
    if(cnt == cnt_load && trenc_bufvld_i && trenc_atready_i)begin
      buf_req ='b1;
    end 
  end

  always_comb begin
    if(trenc_bufvld_i) begin
      if(cnt_load == 2'b0) begin
        //inmouth_dat = pkt_dat;
        inmouth_dat = pkt_dat[ATBWIDTH-1:0];
        atbytes     = (pkt_len >> 3)-1;     
      end 
      else begin
        if(cnt == cnt_load) begin
          //inmouth_dat[ATBWIDTH-1:0] = pkt_dat[0+:ATBWIDTH]  & ATBWIDTH'(-1) >> (ATBWIDTH/8 - atbytes)*8;
          //inmouth_dat = pkt_dat[0+:ATBWIDTH]  & {ATBWIDTH{1'b1}} >> (ATBWIDTH/8 - atbytes)*8;
          //atbytes     = ((pkt_len - (cnt_load-cnt)*ATBWIDTH) >>3)-1;
          inmouth_dat = pkt_dat[ATBWIDTH-1:0];
          atbytes     = ((pkt_len - cnt*ATBWIDTH) >>3)-1;
         end 
         else begin
          //inmouth_dat[ATBWIDTH-1:0] = pkt_dat[pkt_len-1-cnt * ATBWIDTH  -:ATBWIDTH];
          inmouth_dat = pkt_dat[pkt_len-1-cnt * ATBWIDTH  -:ATBWIDTH];
          atbytes     = 3'b111;
        end 
      end 
    end 
    else begin
      //inmouth_dat = {POP_WIDTH{1'b0}};
      inmouth_dat = {ATBWIDTH{1'b0}};
      atbytes     = 3'b0;
    end 
  end

  assign trenc_bufreq_o = buf_req;
  assign trenc_atdata_o = inmouth_dat;
  assign trenc_atbyte_o = atbytes;
  
  // atid indicate core id 0
  always_comb begin
    if(trenc_core_id_i == 2'b00)      trenc_atid_o = TR_ATBID_CORE0;
    else if(trenc_core_id_i == 2'b01) trenc_atid_o = TR_ATBID_CORE1;
    else if(trenc_core_id_i == 2'b10) trenc_atid_o = TR_ATBID_CORE2;
    else if(trenc_core_id_i == 2'b11) trenc_atid_o = TR_ATBID_CORE3;
    else                              trenc_atid_o = 7'b0;
  end
  
  // output atvalid
  
  always_comb  begin
    if(cnt>=0 && trenc_bufvld_i)  trenc_atvalid_o = 1'b1;
    else trenc_atvalid_o = 1'b0;
  end 

  // ATB Flush control
  logic afvalid_q, flush_start;
  logic [5:0] flush_cnt,flush_cnt_q;

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      afvalid_q <= 0; 
    end else begin
      afvalid_q <= trenc_afvalid_i;      
    end
  end 

  assign flush_start = trenc_afvalid_i & ~afvalid_q;

  always_comb begin
    flush_cnt = flush_cnt_q;      
    if(flush_start) begin
      if(trenc_bufempty_i) begin
        flush_cnt = 'b0;
      end else if(trenc_buffull_i) begin
        flush_cnt = DEPTH;
      end else if(trenc_wrptr_i > trenc_rdptr_i) begin
        flush_cnt = trenc_wrptr_i - trenc_rdptr_i;
      end else if(trenc_wrptr_i < trenc_rdptr_i) begin
        flush_cnt = DEPTH + trenc_wrptr_i - trenc_rdptr_i;
      end
    end 
  end

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      flush_cnt_q <= 'b0;
    end else begin
      if(flush_start) begin
        flush_cnt_q <= flush_cnt; 
      end else if (trenc_bufreq_o) begin
        flush_cnt_q <= flush_cnt_q - 'b1;
      end 
    end
  end 
  
  assign trenc_afready_o = trenc_afvalid_i ? (((flush_cnt_q == 'b0) || (trenc_bufempty_i == 1'b1))? 1'b1:1'b0) : 1'b0;
  
endmodule 

