// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
module trenc_pktcomb
  import trenc_pkg::*; 
( 
  input  logic                	      trenc_gclk_i                       ,  //clock
  input  logic                	      trenc_rstn_i                       ,  //reset 
  //input  logic                        trenc_sync_i                       ,  //sync  
  input  logic                        trenc_comp_i                       ,  //sign_compr
  input  logic                        trenc_timectr_i                    ,  //timestamp
  input  logic [1:0]                  trenc_core_id_i                    ,
  //input  logic [SYNC_LEN-1:0]         trenc_syncdata_i                   ,
  input  logic [PAYLOAD_LEN-1:0]      trenc_pkt_i        [INST_WIDTH]    ,
  input  logic [INST_WIDTH-1:0]       trenc_pkt_vld_i                    ,
  input  logic [TIME_WIDTH-1:0]       itime_i                            ,
  input  logic                        trenc_trctrl_enable_i              ,  
  input  logic  				              trenc_trctrl_start_i               ,
  input  logic                        trenc_trmode_i                     ,
  input  logic                        trenc_teinstmode_i                 ,
  input  logic[INST_WIDTH-1:0]        trenc_interrupt_i                  ,
  input  logic                        trenc_stop_i                       ,
  input  logic                        trenc_pkt_lost_i                   ,
  input  pkt_format_t                 trenc_pkt_fmt_i     [INST_WIDTH]   ,
  input  pkt_sync_sformat_t           trenc_sync_sfmt_i   [INST_WIDTH]   ,
  output logic [INST_WIDTH-1:0]       trenc_pkt_vld_o                    ,
  output logic [PKTDATA_LEN-1:0]      trenc_data_o        [INST_WIDTH]   ,
  output logic [PKTDATA_WIDTH-1:0]    trenc_data_len_o    [INST_WIDTH]
);

   
  pkt_format_t       trenc_pkt_fmt       [INST_WIDTH];
  pkt_sync_sformat_t trenc_sync_sfmt     [INST_WIDTH];
  logic [INST_WIDTH-1:0]                    interrupt;
  logic [PAYLOAD_LEN-1:0] trenc_pkt_comb [INST_WIDTH];
  logic [INST_WIDTH-1:0]                trenc_pkt_vld;    
  logic 		   		                            is_comp;
  logic [TIME_WIDTH-1:0]                        itime;
  logic                                trenc_pkt_lost;
 
  
  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin 
    if(!trenc_rstn_i) begin
      trenc_pkt_lost <= 1'b0;
    end 
    else begin
      trenc_pkt_lost <= trenc_pkt_lost_i;
    end
  end 

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin 
    if (!trenc_rstn_i) begin
      for(int w_pkt_comb = 0 ;w_pkt_comb < INST_WIDTH;w_pkt_comb = w_pkt_comb+1) begin
        trenc_pkt_comb[w_pkt_comb]        <= {PAYLOAD_LEN{1'b0}};
        trenc_pkt_vld [w_pkt_comb]        <= {3{1'b0}};
        trenc_pkt_fmt [w_pkt_comb]        <= FORMAT0;
        trenc_sync_sfmt[w_pkt_comb]       <= SF_START;
        interrupt[w_pkt_comb]             <= 3'b0;            
      end 
    end else begin
      for(int w_pkt_comb = 0 ;w_pkt_comb < INST_WIDTH;w_pkt_comb = w_pkt_comb+1) begin
        trenc_pkt_comb[w_pkt_comb]         <= trenc_pkt_i    [w_pkt_comb];
        trenc_pkt_vld [w_pkt_comb]         <= trenc_pkt_vld_i[w_pkt_comb];
        trenc_pkt_fmt                      <= trenc_pkt_fmt_i;
        trenc_sync_sfmt                    <= trenc_sync_sfmt_i;
        interrupt                          <= trenc_interrupt_i;
      end 
    end 
  end
/*  
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      itime   <= {TIME_WIDTH{1'b0}};
    end 
    else begin
      itime   <= itime_i;
    end 
  end 
*/ 
  assign itime = itime_i;

  logic trace_start,trace_stop_q,trace_stop_p;
  //logic trace_stop,
  typedef enum logic {IDLE ,TRACING} pkt_state;
  pkt_state pkt_cs, pkt_ns;   
  logic trenc_reseted,trenc_started,trenc_stoped,trenc_started_lock,trenc_started_q;
  assign trenc_started          = trenc_trctrl_enable_i & trenc_trctrl_start_i ;
  assign trenc_stoped           = ~trenc_started;
  assign trenc_reseted          = trenc_rstn_i;

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) trenc_started_q <= 'b0;
    else trenc_started_q <= trenc_started;
  end 
  assign trenc_started_lock = trenc_started & ~trenc_started_q;

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
     if(!trenc_rstn_i) pkt_cs <= IDLE;
     else              pkt_cs <= pkt_ns;
  end

  always_comb begin
     pkt_ns = pkt_cs;
     case(pkt_cs)
        IDLE : begin
        	if(trenc_started_lock && trenc_reseted) pkt_ns = TRACING;
          else pkt_ns = IDLE;
        end
        TRACING : begin
        	if(trenc_stoped || !trenc_reseted ) pkt_ns = IDLE;
          else pkt_ns = TRACING;
        end
     endcase
  end

  assign trace_start  = ((pkt_cs == IDLE) && (pkt_ns == TRACING)) ? 1'b1 : 1'b0;

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      trace_stop_p <= 'b0;
      trace_stop_q <= 'b0;
    end else begin
      trace_stop_p <= trenc_stop_i;
      trace_stop_q <= trace_stop_p;
    end 
  end

  logic[1:0] ioption;
  //logic      ienable;
  logic encoder_mode;
  //assign ioption[0]   = trenc_comp_i   ? 1'b1:'b0;     // compress?
  //assign ioption[1]   = trenc_trmode_i ? 1'b1:'b0;     //full_addr or diff_addr 
  assign ioption[0]   = 1'b0;     // compress?
  assign ioption[1]   = 1'b1;     //full_addr or diff_addr 
  assign encoder_mode = trace_stop_q   ? 1'b0:trenc_teinstmode_i;
  //assign ienable      = trenc_started  ? 1'b1:1'b0;


  //this code check whether pkt need compressed
  assign is_comp = trenc_comp_i;
  logic [PKTDATA_LEN-1:0]                       trenc_data         [INST_WIDTH];
  logic [PKTDATA_WIDTH-1:0]                     trenc_data_len     [INST_WIDTH];
    
  logic trenc_support_vld;

  always_comb begin
    trenc_support_vld ='b0;
    if(trace_start) begin
      if(trenc_timectr_i) begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b1,16'b0,4'b1111,1'b1,encoder_mode,2'b00,ioption,{6{ioption[0]}}};
        trenc_data_len[0]  = HEADER_LEN + 3 + TIME_LEN + 16;
        trenc_support_vld  = 1'b1; 
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end else begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b0,4'b1111,1'b1,encoder_mode,2'b00,ioption,{6{ioption[0]}}};
        trenc_data_len[0]  = HEADER_LEN + 3 + 16;
        trenc_support_vld  = 1'b1;
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end 
    end
    else if(trenc_pkt_lost) begin
      if(trenc_timectr_i) begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b1,16'b0,4'b1111,1'b1,encoder_mode,2'b10,ioption,{6{ioption[0]}}}; 
        trenc_data_len[0]  = HEADER_LEN + 3 + TIME_LEN + 16;
        trenc_support_vld  = 1'b1;
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end else begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b0,4'b1111,1'b1,encoder_mode,2'b10,ioption,{6{ioption[0]}}};
        trenc_data_len[0]  = HEADER_LEN + 3 + 16;
        trenc_support_vld  = 1'b1;
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end       
    end
    else if(trace_stop_q) begin
      if(trenc_timectr_i) begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b1,16'b0,4'b1111,1'b0,encoder_mode,2'b01,ioption,{6{ioption[0]}}}; 
        trenc_data_len[0]  = HEADER_LEN + 3 + TIME_LEN + 16;
        trenc_support_vld  = 1'b1;
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end else begin
        trenc_data[0]      = {5'b00010,trenc_core_id_i,1'b0,4'b1111,1'b0,encoder_mode,2'b01,ioption,{6{ioption[0]}}};
        trenc_data_len[0]  = HEADER_LEN + 3 + 16;
        trenc_support_vld  = 1'b1;
        trenc_data[1]      = 'b0;
        trenc_data_len[1]  = 'b0;
        trenc_data[2]      = 'b0;
        trenc_data_len[2]  = 'b0;
        trenc_data[3]      = 'b0;
        trenc_data_len[3]  = 'b0;
      end 
    end else begin
      for(int i=0;i<INST_WIDTH;i=i+1) begin
        trenc_data[i]     = {PKTDATA_LEN{1'b0}};
        trenc_data_len[i] = {PKTDATA_WIDTH{1'b0}};
        //if(trenc_trmode_i) begin 
        if(trenc_pkt_vld[i]) begin
          case(trenc_pkt_fmt[i])
            FORMAT3:begin
              case(trenc_sync_sfmt[i]) 
                SF_START:begin
                  if(trenc_timectr_i) begin
                    trenc_data[i] = {5'b01011,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_START_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                    trenc_data_len[i] = SF_START_WIDTH + HEADER_TIME_WIDRH + 6;
                  end else begin
                    trenc_data[i] = {5'b01011,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_START_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                    trenc_data_len [i] = SF_START_WIDTH + HEADER_NTIME_WIDRH + 6;
                  end
                end 
                SF_TRAP:begin
                  if(!interrupt[i]) begin
                    if(trenc_timectr_i) begin
                      trenc_data[i][SF_TRAP_INT_WIDTH + HEADER_TIME_WIDRH+5:0]={5'b10001,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_TRAP_INT_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                      trenc_data_len [i] = SF_TRAP_INT_WIDTH + HEADER_TIME_WIDRH+6; 
                    end else begin
                      trenc_data[i][SF_TRAP_INT_WIDTH + HEADER_NTIME_WIDRH+5:0]={5'b10001,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_TRAP_INT_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                      trenc_data_len [i] = SF_TRAP_INT_WIDTH + HEADER_NTIME_WIDRH+6; 
                    end 
                  end else begin
                    if(trenc_timectr_i) begin
                      trenc_data[i][SF_TRAP_NINT_WIDTH + HEADER_TIME_WIDRH+5:0]={5'b01100,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_TRAP_NINT_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                      trenc_data_len [i] = SF_TRAP_NINT_WIDTH + HEADER_TIME_WIDRH +6; 
                    end else begin
                      trenc_data[i][SF_TRAP_NINT_WIDTH + HEADER_NTIME_WIDRH+5:0] = {5'b01100,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_TRAP_NINT_WIDTH-1:0],{6{trenc_pkt_comb[i][0]}}};
                      trenc_data_len [i] = SF_TRAP_NINT_WIDTH + HEADER_NTIME_WIDRH + 6; 
                    end 
                  end
                end
              endcase 
            end 
            FORMAT2:begin
              if(trenc_timectr_i) begin
                trenc_data[i][SF_ADDR_WIDTH + HEADER_TIME_WIDRH + 4:0] = {5'b00110,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_ADDR_WIDTH-1:0],{5{trenc_pkt_comb[i][0]}}};
                trenc_data_len [i] = SF_ADDR_WIDTH + HEADER_TIME_WIDRH + 5;
              end else begin
                trenc_data[i][SF_ADDR_WIDTH + HEADER_NTIME_WIDRH + 4:0] = {5'b00110,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_ADDR_WIDTH-1:0],{5{trenc_pkt_comb[i][0]}}};
                trenc_data_len [i] = SF_ADDR_WIDTH + HEADER_NTIME_WIDRH + 5;
              end 
            end 
            FORMAT1:begin
              case(trenc_sync_sfmt[i])
                SF_BRA_ADDR:begin
                  if(trenc_timectr_i) begin
                    trenc_data[i][SF_BRA_ADDR_WIDTH + HEADER_TIME_WIDRH:0] = {5'b01010,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_BRA_ADDR_WIDTH-1:0],{1{trenc_pkt_comb[i][0]}}};
                    trenc_data_len [i] = SF_BRA_ADDR_WIDTH + HEADER_TIME_WIDRH + 1;
                  end else begin
                    trenc_data[i][SF_BRA_ADDR_WIDTH + HEADER_NTIME_WIDRH:0] = {5'b01010,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_BRA_ADDR_WIDTH-1:0],{1{trenc_pkt_comb[i][0]}}};
                    trenc_data_len [i] = SF_BRA_ADDR_WIDTH + HEADER_NTIME_WIDRH + 1;
                  end 
                end 
                SF_BRA_NADDR:begin
                  if(trenc_timectr_i) begin
                    trenc_data[i][SF_BRA_NADDR_WIDTH + HEADER_TIME_WIDRH+1:0] = {5'b00101,trenc_core_id_i,1'b1,itime,trenc_pkt_comb[i][SF_BRA_NADDR_WIDTH-1:0],{2{trenc_pkt_comb[i][0]}}};
                    trenc_data_len [i] = SF_BRA_NADDR_WIDTH + HEADER_TIME_WIDRH + 2;
                  end else begin
                    trenc_data[i][SF_BRA_NADDR_WIDTH + HEADER_NTIME_WIDRH+1:0] = {5'b00101,trenc_core_id_i,1'b0,trenc_pkt_comb[i][SF_BRA_NADDR_WIDTH-1:0],{2{trenc_pkt_comb[i][0]}}};
                    trenc_data_len [i] = SF_BRA_NADDR_WIDTH + HEADER_NTIME_WIDRH + 2;
                  end 
                end 
              endcase 
            end 
          endcase
        end 
        //end
      end
    end 
  end 

  logic [INST_WIDTH-1:0] trenc_pkt_vld_tmp;  
  assign trenc_pkt_vld_tmp[INST_WIDTH-1:1] = trenc_pkt_lost ? 'b0:trenc_pkt_vld[INST_WIDTH-1:1];
  assign trenc_pkt_vld_tmp[0]   = trenc_pkt_vld[0] | trenc_support_vld ;
  //assign trenc_pkt_vld_o = trenc_pkt_vld_tmp;

  always_comb begin
    case(trenc_pkt_vld_tmp)
      4'b0000:begin
        for(int i =0;i<INST_WIDTH;i++) begin
          trenc_data_o[i]    = {PKTDATA_LEN{1'b0}};
          trenc_data_len_o[i]= {PKTDATA_WIDTH{1'b0}};
        end
        trenc_pkt_vld_o    = {INST_WIDTH{1'b0}};
      end 
      4'b0001:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = 1'b0;
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b0010:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[1] = 1'b0;
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[1];
        trenc_data_len_o[1]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[1];
        trenc_data_o[1]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end 
      4'b0100:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[1] = 1'b0;
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[2];
        trenc_data_len_o[1]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[2];
        trenc_data_o[1]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b1000:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[1] = 1'b0;
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[3];
        trenc_data_len_o[1]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[3];
        trenc_data_o[1]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b0011:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[1];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[1];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end 
      4'b0101:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[2];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[2];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b1001:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[3];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[3];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b0110:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[1];
        trenc_data_len_o[1]= trenc_data_len[2];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[1];
        trenc_data_o[1]    = trenc_data[2];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end 
      4'b1010:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[1];
        trenc_data_len_o[1]= trenc_data_len[3];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[1];
        trenc_data_o[1]    = trenc_data[3];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end 
      4'b1100:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[2] = 1'b0;
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[2];
        trenc_data_len_o[1]= trenc_data_len[3];
        trenc_data_len_o[2]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[2];
        trenc_data_o[1]    = trenc_data[3];
        trenc_data_o[2]    = {PKTDATA_LEN{1'b0}};
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end 
      4'b0111:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[2] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[1];
        trenc_data_len_o[2]= trenc_data_len[2];
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[1];
        trenc_data_o[2]    = trenc_data[2];
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b1011:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[2] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[1];
        trenc_data_len_o[2]= trenc_data_len[3];
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[1];
        trenc_data_o[2]    = trenc_data[3];
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b1101:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[2] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[2];
        trenc_data_len_o[2]= trenc_data_len[3];
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[2];
        trenc_data_o[2]    = trenc_data[3];
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};
      end
      4'b1110:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[2] = trenc_pkt_vld_tmp[3];
        trenc_pkt_vld_o[3] = 1'b0;
        trenc_data_len_o[0]= trenc_data_len[1];
        trenc_data_len_o[1]= trenc_data_len[2];
        trenc_data_len_o[2]= trenc_data_len[3];
        trenc_data_len_o[3]= {PKTDATA_WIDTH{1'b0}};
        trenc_data_o[0]    = trenc_data[1];
        trenc_data_o[1]    = trenc_data[2];
        trenc_data_o[2]    = trenc_data[3];
        trenc_data_o[3]    = {PKTDATA_LEN{1'b0}};

      end
      4'b1111:begin
        trenc_pkt_vld_o[0] = trenc_pkt_vld_tmp[0];
        trenc_pkt_vld_o[1] = trenc_pkt_vld_tmp[1];
        trenc_pkt_vld_o[2] = trenc_pkt_vld_tmp[2];
        trenc_pkt_vld_o[3] = trenc_pkt_vld_tmp[3];
        trenc_data_len_o[0]= trenc_data_len[0];
        trenc_data_len_o[1]= trenc_data_len[1];
        trenc_data_len_o[2]= trenc_data_len[2];
        trenc_data_len_o[3]= trenc_data_len[3];
        trenc_data_o[0]    = trenc_data[0];
        trenc_data_o[1]    = trenc_data[1];
        trenc_data_o[2]    = trenc_data[2];
        trenc_data_o[3]    = trenc_data[3];
      end
      default:begin
        for(int i =0;i<INST_WIDTH;i++) begin
          trenc_data_o[i]    = {PKTDATA_LEN{1'b0}};
          trenc_data_len_o[i]= {PKTDATA_WIDTH{1'b0}};
        end
        trenc_pkt_vld_o      = {INST_WIDTH{1'b0}};
      end 
    endcase 
  end 





/*
  always_comb begin
    for(int i =0;i<INST_WIDTH;i++) begin
      trenc_data_o[i]    = trenc_data[i];
      trenc_data_len_o[i]= trenc_data_len[i];
    end
  end 
*/


endmodule 

