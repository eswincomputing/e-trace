// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
  module trenc_algo
  import trenc_pkg::*;
    ( 
      input  logic                	               trenc_gclk_i                        ,  //clock
      input  logic                	               trenc_rstn_i                        ,  //reset
      input  microop_t      inter_uop_i            [INST_WIDTH-1]                      ,  //input uop
      input  logic                                 trenc_mode_i                        ,  //trenc mode 
      input  logic [TIME_WIDTH-1:0]                trenc_expire_time_i                 ,
      //input  logic [APBDWIDTH-1:0]                 trenc_filter_i                      ,
      //input  logic [APBDWIDTH-1:0]                 trenc_filaddr0h_i                   ,
      //input  logic [APBDWIDTH-1:0]                 trenc_filaddr0l_i                   ,
      //input  logic [APBDWIDTH-1:0]                 trenc_filaddr1h_i                   ,
      //input  logic [APBDWIDTH-1:0]                 trenc_filaddr1l_i                   ,
      input  logic                                 trenc_compress_i                    ,
      input  logic                                 trenc_trctrl_enable_i               ,  //need confirm
      input  logic  				                       trenc_trctrl_start_i                ,
      //input  logic                                 trenc_trmode_i                      ,
      input  logic                                 trenc_pktlost_i                     ,  // form fifo
      input  logic [TIME_WIDTH-1:0]                trenc_itime_i                       ,
      input  logic                                 trenc_async_expt_vld_i              ,
      input  logic                                 trenc_int_vld_i                     ,
      output logic [INST_WIDTH-1:0]                trenc_pkt_vld_o                     ,
      output logic [PAYLOAD_LEN-1:0]               trenc_pkt_o            [INST_WIDTH] ,
      output logic [INST_WIDTH-1:0]                trenc_interrupt_o                   ,
      output logic                                 trenc_stop_o                        ,
      output pkt_format_t                          trenc_pkt_fmt_o        [INST_WIDTH] ,
      output pkt_sync_sformat_t                    trenc_sync_sfmt_o      [INST_WIDTH]             

    );
  
  localparam PREVIOUS_SLOT   = 0 ;
  localparam CURRENT_SLOT    = 1 ;
  localparam NEXT_SLOT       = 2 ;
  localparam INST_NUM        = 0 ;
  localparam CAUSE           = 27;
  localparam IADDR_WIDTH     = 79;
  localparam ITYPE_WIDTH     = 75;

  logic [TIME_WIDTH-1:0] trenc_itime;
  logic trenc_async_expt_vld;
  logic trenc_int_vld;
  logic [5:0]trenc_async_cause;
  logic [39:0]trenc_async_tval;
  logic trace_start,trace_stop,trace_stop_q,trace_stop_r;
  typedef enum logic [1:0] {IDLE,START,TRACING} pkt_state;
  pkt_state pkt_cs, pkt_ns;   
  logic trenc_reseted,trenc_stoped;
  logic trenc_started,trenc_started_lock,trenc_started_q;
  logic tracing,tracing_q,trace_work;
  logic [INST_WIDTH-1:0]    resync;
  logic trace_first_inst;
  logic trace_first_instruction;
  logic trenc_pktlost_q;
  //logic trenc_pktlost_r;
  microop_t    interface_uop_slot        [INST_WIDTH+2]   ;
  microop_t    microop_uop               [INST_WIDTH-1]   ;
  microop_t    inter_uop                 [INST_WIDTH]     ;
  logic [INST_WIDTH-1:0]                    excp_has_reported;
  logic [2:0]                                     inst_number;
  //logic [INST_WIDTH-1:0]               interface_uop_reported;
  logic [INST_WIDTH:0]                 interface_uop_reported;
  logic [INST_WIDTH-1:0]                         uop_reported;
  logic [INST_WIDTH-1:0]                             reported;
  logic [1:0]                                     fold_number;

/*
 *trace_encoder state:
 *trenc_started           : open  register,  enable  register & active register
 *trenc_stoped            : close register,  disable register & active register
 *tracing                 : FSM state, trace encoder tracing instruction stream
 *trace_stop              : FSM state, disable trace_encoder by close register
 *trace_start             : FSM state, enable trace_encoder  by open register 
 *trace_first_instruction : After trace start First instruction
 *trace_first_inst        : include 
 *caution:when trace start First instruction is not coming 
 */
  assign trenc_started          = trenc_trctrl_enable_i & trenc_trctrl_start_i;
  assign trenc_stoped           = ~trenc_started;
  assign trenc_reseted          = trenc_rstn_i;
 
  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      trenc_async_expt_vld <= 1'b0;
      trenc_int_vld        <= 1'b0;
      trenc_async_cause    <= 6'b0;
      trenc_async_tval     <= 40'd0;
    end else begin
      trenc_async_expt_vld <= trenc_async_expt_vld_i;
      trenc_int_vld        <= trenc_int_vld_i; 
      trenc_async_cause    <= inter_uop_i[0].cause;
      trenc_async_tval     <= inter_uop_i[0].tval;
    end 
  end 


  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      for(int i=0;i<INST_WIDTH-1;i=i+1) microop_uop[i] <= 'b0;
    end 
    else if(~trenc_started) begin
      for(int i=0;i<INST_WIDTH-1;i=i+1) microop_uop[i] <= 'b0;    
    end 
    else if (trenc_started) begin
      for(int i=0;i<INST_WIDTH-1;i=i+1) microop_uop[i] <= inter_uop_i[i];
    end 
  end

  assign fold_number  = ((microop_uop[0].inst_num > 2'd1 && microop_uop[0].ivalid) ? 1'b1:1'b0) 
                       +((microop_uop[1].inst_num > 2'd1 && microop_uop[1].ivalid) ? 1'b1:1'b0) 
                       +((microop_uop[2].inst_num > 2'd1 && microop_uop[2].ivalid) ? 1'b1:1'b0);

  always_comb begin
    inter_uop[0] = microop_uop[0];
    inter_uop[1] = microop_uop[1];
    inter_uop[2] = microop_uop[2];
    inter_uop[3] = 'd0;
    if(fold_number == 'd1) begin
      if(microop_uop[0].ivalid && microop_uop[1].ivalid && microop_uop[2].ivalid ) begin
        if(microop_uop[0].inst_num > 2'd1) begin          //microop[0] is fold 
          inter_uop[0]       = microop_uop[0];
          inter_uop[1].iaddr = microop_uop[0].iaddr + microop_uop[0].iretire - (microop_uop[0].ilastsize ? {37'h0,2'h2}:{37'h0,2'h1});
          inter_uop[1][IADDR_WIDTH-1:0] = {microop_uop[0][CAUSE+:52],(microop_uop[0].ilastsize? 3'b010:3'b001),microop_uop[0][INST_NUM+:24]};
          inter_uop[2]       = microop_uop[1];
          inter_uop[3]       = microop_uop[2];
        end else if(microop_uop[1].inst_num > 2'd1) begin //microop[1] is fold 
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[1];
          inter_uop[2].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize? {37'h0,2'h2}:{37'h0,2'h1});          
          inter_uop[2][IADDR_WIDTH-1:0] = {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]};
          inter_uop[3]       = microop_uop[2];
        end else begin                                    //microop[2] is fold 
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[1];
          inter_uop[2]       = microop_uop[2];
          inter_uop[3].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize? {37'h0,2'h2}:{37'h0,2'h1});
          inter_uop[3][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]};
        end
      end 
      else if(microop_uop[0].ivalid && microop_uop[1].ivalid) begin  //microop_t[0] valid  &&  microop_t[1] valid
        if(microop_uop[0].inst_num > 2'd1) begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1].iaddr = microop_uop[0].iaddr + microop_uop[0].iretire - (microop_uop[0].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[0][CAUSE+:52],(microop_uop[0].ilastsize? 3'b010:3'b001),microop_uop[0][INST_NUM+:24]};       
          inter_uop[2]       = microop_uop[1]; 
        end else begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[1];              
          inter_uop[2].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize?'h2:'h1);
          inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]}; 
        end 
      end
      else if(microop_uop[0].ivalid && microop_uop[2].ivalid) begin //microop_t[0] valid  &&  microop_t[2] valid
        if(microop_uop[0].inst_num > 2'd1) begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1].iaddr = microop_uop[0].iaddr + microop_uop[0].iretire - (microop_uop[0].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[0][CAUSE+:52],(microop_uop[0].ilastsize? 3'b010:3'b001),microop_uop[0][INST_NUM+:24]};       
          inter_uop[2]       = microop_uop[2]; 
        end else begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[2];              
          inter_uop[2].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
          inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]}; 
        end 
      end 
      else if(microop_uop[1].ivalid && microop_uop[2].ivalid) begin //microop_t[1] valid  &&  microop_t[2] valid
       if(microop_uop[1].inst_num > 2'd1) begin
          inter_uop[0]       = microop_uop[1];
          inter_uop[1].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]};       
          inter_uop[2]       = microop_uop[2]; 
        end else begin
          inter_uop[0]       = microop_uop[1];
          inter_uop[1]       = microop_uop[2];              
          inter_uop[2].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
          inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]}; 
        end         
      end 
      else if(microop_uop[0].ivalid) begin
          inter_uop[0].itype = microop_uop[0].itype == 'd2 ? 'd0 : microop_uop[0].itype;
          inter_uop[0].iaddr = microop_uop[0].iaddr;
          inter_uop[0][IADDR_WIDTH-5:0] =  {microop_uop[0][CAUSE+:48],(microop_uop[0].ilastsize? 3'b010:3'b001),microop_uop[0][INST_NUM+:24]};  
          inter_uop[1].iaddr = microop_uop[0].iaddr + microop_uop[0].iretire - (microop_uop[0].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[0][CAUSE+:52],(microop_uop[0].ilastsize? 3'b010:3'b001),microop_uop[0][INST_NUM+:24]};  
      end 
      else if(microop_uop[1].ivalid) begin
          inter_uop[0].itype = microop_uop[1].itype == 'd2 ? 'd0 : microop_uop[1].itype;
          inter_uop[0].iaddr = microop_uop[1].iaddr;
          inter_uop[0][IADDR_WIDTH-5:0] =  {microop_uop[1][CAUSE+:48],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]};  
          inter_uop[1].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]};  
      end 
      else begin
          inter_uop[0].itype = microop_uop[2].itype == 'd2 ? 'd0 : microop_uop[2].itype;
          inter_uop[0].iaddr = microop_uop[2].iaddr;
          inter_uop[0][IADDR_WIDTH-5:0] =  {microop_uop[2][CAUSE+:48],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]};  
          inter_uop[1].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
          inter_uop[1][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]};  
      end 
    end
    else if(fold_number == 'd2) begin
      if(microop_uop[0].ivalid && microop_uop[1].ivalid && microop_uop[2].ivalid) begin
        if(microop_uop[2].inst_num > 2'd1) begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[1];              
          inter_uop[2]       = microop_uop[2];              
          inter_uop[3].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
          inter_uop[3][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]}; 
        end 
        else begin
          inter_uop[0]       = microop_uop[0];
          inter_uop[1]       = microop_uop[1];              
          inter_uop[2].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize?'h2:'h1);
          inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]}; 
          inter_uop[3]       = microop_uop[2]; 
        end 
      end 
      else if (microop_uop[0].ivalid && microop_uop[1].ivalid) begin
        inter_uop[0]       = microop_uop[0];
        inter_uop[1]       = microop_uop[1];              
        inter_uop[2].iaddr = microop_uop[1].iaddr + microop_uop[1].iretire - (microop_uop[1].ilastsize?'h2:'h1);
        inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[1][CAUSE+:52],(microop_uop[1].ilastsize? 3'b010:3'b001),microop_uop[1][INST_NUM+:24]}; 
      end 
      else if (microop_uop[0].ivalid && microop_uop[2].ivalid) begin
        inter_uop[0]       = microop_uop[0];
        inter_uop[1]       = microop_uop[2];              
        inter_uop[2].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
        inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]};         
      end
      else if(microop_uop[1].ivalid  && microop_uop[2].ivalid) begin
        inter_uop[0]       = microop_uop[1];
        inter_uop[1]       = microop_uop[2];              
        inter_uop[2].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
        inter_uop[2][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]};          
      end 
      else begin
        inter_uop[0] = microop_uop[0];
        inter_uop[1] = microop_uop[1];
        inter_uop[2] = microop_uop[2];
        inter_uop[3] = 'd0;
      end 
    end 
    else if(fold_number == 'd3) begin
      inter_uop[0]       = microop_uop[0];
      inter_uop[1]       = microop_uop[1];              
      inter_uop[2]       = microop_uop[2];              
      inter_uop[3].iaddr = microop_uop[2].iaddr + microop_uop[2].iretire - (microop_uop[2].ilastsize?'h2:'h1);
      inter_uop[3][IADDR_WIDTH-1:0] =  {microop_uop[2][CAUSE+:52],(microop_uop[2].ilastsize? 3'b010:3'b001),microop_uop[2][INST_NUM+:24]}; 
    end 
  end


  
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      trenc_itime <= {TIME_WIDTH{1'b0}};
    end else begin 
      trenc_itime <= trenc_itime_i; 
    end 
  end 

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin 
    if(!trenc_rstn_i) begin
      for (int j=0 ;j<INST_WIDTH+2;j=j+1) interface_uop_slot[j] <= 'b0;	
    end 
    else if(trace_stop_r) begin
      for (int i=0 ;i<INST_WIDTH+2;i=i+1) interface_uop_slot[i] <= 'b0;	
    end 
    else if(trace_stop) begin
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4]} 
      <= {interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]};
      interface_uop_slot[5] <= 'b0;    
    end
    else if(inter_uop[3].ivalid && inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin //retire 3 
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[4],interface_uop_slot[5],inter_uop[0],inter_uop[1],inter_uop[2],inter_uop[3]}; 
    end 
    else if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin //retire 3 
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[0],inter_uop[1],inter_uop[2]}; 
    end
    else if(inter_uop[0].ivalid && inter_uop[1].ivalid) begin //retire 0 1 
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[0],inter_uop[1]}; 
    end 
    else if(inter_uop[0].ivalid && inter_uop[2].ivalid) begin //retire 0 2 
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[0],inter_uop[2]}; 
    end 
    else if(inter_uop[1].ivalid && inter_uop[2].ivalid) begin //retire 1 2 
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[1],inter_uop[2]}; 
    end  
    else if(inter_uop[0].ivalid) begin //retire 0
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[0]}; 
    end 
    else if(inter_uop[1].ivalid) begin
     {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[1]}; 
    end 
    else if(inter_uop[2].ivalid) begin
      {interface_uop_slot[0],interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5]} 
      <= {interface_uop_slot[1],interface_uop_slot[2],interface_uop_slot[3],interface_uop_slot[4],interface_uop_slot[5],inter_uop[2]}; 
    end 
    else if(trenc_async_expt_vld) begin
      interface_uop_slot[5].itype     <= 4'd1;
      interface_uop_slot[5].iaddr     <= interface_uop_slot[5].iaddr;
      interface_uop_slot[5].priv      <= interface_uop_slot[5].priv;
      interface_uop_slot[5].tval      <= trenc_async_tval;
      interface_uop_slot[5].cause     <= trenc_async_cause;
      interface_uop_slot[5].iretire   <= interface_uop_slot[5].iretire;
      interface_uop_slot[5].ilastsize <= interface_uop_slot[5].ilastsize;
      interface_uop_slot[5].cont      <= interface_uop_slot[5].cont;
    end
    else if(trenc_int_vld)begin
      interface_uop_slot[5].itype     <= 4'd2;
      interface_uop_slot[5].iaddr     <= interface_uop_slot[5].iaddr;
      interface_uop_slot[5].priv      <= interface_uop_slot[5].priv;
      interface_uop_slot[5].tval      <= trenc_async_tval;
      interface_uop_slot[5].cause     <= trenc_async_cause;
      interface_uop_slot[5].iretire   <= interface_uop_slot[5].iretire;
      interface_uop_slot[5].ilastsize <= interface_uop_slot[5].ilastsize;
      interface_uop_slot[5].cont      <= interface_uop_slot[5].cont;
    end
  end

  //always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
  //  if(!trenc_rstn_i) begin
  //    interface_uop_reported <= 3'b0;	
  //  end else if(trace_stop) begin
  //    {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2]} 
  //    <= {excp_has_reported[0],excp_has_reported[1],excp_has_reported[2]};
  //  end else if(inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
  //    if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid ) begin
  //      interface_uop_reported[0] 
  //      <= excp_has_reported[2]; 
  //    end else if((inter_uop[2].ivalid && inter_uop[1].ivalid) || (inter_uop[1].ivalid && inter_uop[0].ivalid) || (inter_uop[2].ivalid && inter_uop[0].ivalid) ) begin
  //      {interface_uop_reported[0],interface_uop_reported[1]} 
  //      <= {excp_has_reported[1],excp_has_reported[2]}; 
  //    end else if(inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
  //      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2]} 
  //      <= {excp_has_reported[0],excp_has_reported[1],excp_has_reported[2]};  
  //    end 
    //end else begin
    //  if(inst_num == 'd3) begin
    //    interface_uop_reported[0] 
    //    <= excp_has_reported[2]; 
    //  end else if(inst_num == 'd2) begin
    //    {interface_uop_reported[0],interface_uop_reported[1]} 
    //    <= {excp_has_reported[1],excp_has_reported[2]}; 
    //  end else if(inst_num == 'd1) begin
    //    {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2]} 
    //    <= {excp_has_reported[0],excp_has_reported[1],excp_has_reported[2]}; 
    //  end
    //end
  //end 
  
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      uop_reported[0] <= 1'b0;
      uop_reported[1] <= 1'b0;
      uop_reported[2] <= 1'b0;
      uop_reported[3] <= 1'b0;
    end
    else if (excp_has_reported[0]) begin
      uop_reported[0] <= 1'b1;
      uop_reported[1] <= 1'b0;
      uop_reported[2] <= 1'b0;
      uop_reported[3] <= 1'b0;
    end
    else if (excp_has_reported[1]) begin
      uop_reported[0] <= 1'b0;
      uop_reported[1] <= 1'b1;
      uop_reported[2] <= 1'b0;
      uop_reported[3] <= 1'b0;
    end 
    else if (excp_has_reported[2]) begin
      uop_reported[0] <= 1'b0;
      uop_reported[1] <= 1'b0;
      uop_reported[2] <= 1'b1;
      uop_reported[3] <= 1'b0;
    end 
    else if (excp_has_reported[3]) begin
      uop_reported[0] <= 1'b0;
      uop_reported[1] <= 1'b0;
      uop_reported[2] <= 1'b0;
      uop_reported[3] <= 1'b1;
    end 
    else if (inter_uop[3].ivalid ||inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
      uop_reported[0] <= 1'b0;
      uop_reported[1] <= 1'b0;
      uop_reported[2] <= 1'b0;
      uop_reported[3] <= 1'b0;
    end 
  end 
/*
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      interface_uop_reported[0] <= 1'b0;
      interface_uop_reported[1] <= 1'b0;
      interface_uop_reported[2] <= 1'b0;
      interface_uop_reported[3] <= 1'b0;
    end 
    else if(inter_uop[3].ivalid && inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3]} 
      <= {uop_reported[0],uop_reported[1],uop_reported[2],uop_reported[3]};    
    end 
    else if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3]} 
      <= {interface_uop_reported[0],uop_reported[1],uop_reported[2],uop_reported[3]};    
    end 
    else if((inter_uop[2].ivalid && inter_uop[1].ivalid) || (inter_uop[1].ivalid && inter_uop[0].ivalid) || (inter_uop[2].ivalid && inter_uop[0].ivalid)) begin
    //else if(inter_uop[2].ivalid && inter_uop[1].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3]} 
      <= {uop_reported[2],uop_reported[3],interface_uop_reported[2],interface_uop_reported[3]}; 
    end 
    else if(inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
    //else if(inter_uop[2].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3]} 
      <= {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],uop_reported[3]}; 
    end
  end 
  
*/
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      interface_uop_reported[0] <= 1'b0;
      interface_uop_reported[1] <= 1'b0;
      interface_uop_reported[2] <= 1'b0;
      interface_uop_reported[3] <= 1'b0;
      interface_uop_reported[4] <= 1'b0;
    end 
    else if(inter_uop[3].ivalid && inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]} 
      //<= {uop_reported[2],uop_reported[3],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]};    
      <= {uop_reported[3],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]};    
    end 
    else if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]} 
      <= {uop_reported[2],uop_reported[3],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]};    
    end 
    else if((inter_uop[2].ivalid && inter_uop[1].ivalid) || (inter_uop[1].ivalid && inter_uop[0].ivalid) || (inter_uop[2].ivalid && inter_uop[0].ivalid)) begin
    //else if(inter_uop[2].ivalid && inter_uop[1].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]} 
      <= {uop_reported[1],uop_reported[2],uop_reported[3],interface_uop_reported[3],interface_uop_reported[4]}; 
    end 
    else if(inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
    //else if(inter_uop[2].ivalid) begin
      {interface_uop_reported[0],interface_uop_reported[1],interface_uop_reported[2],interface_uop_reported[3],interface_uop_reported[4]} 
      <= {uop_reported[0],uop_reported[1],uop_reported[2],uop_reported[3],interface_uop_reported[4]}; 
    end
  end 
  


  assign  reported[0] = interface_uop_reported[0];
  assign  reported[1] = interface_uop_reported[1] || excp_has_reported[0];
  assign  reported[2] = interface_uop_reported[2] || excp_has_reported[1];
  assign  reported[3] = interface_uop_reported[3] || excp_has_reported[2];
  logic ivalid; 
  assign ivalid = interface_uop_slot[1].ivalid | interface_uop_slot[2].ivalid | interface_uop_slot[3].ivalid | interface_uop_slot[4].ivalid;
  
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      trenc_started_q <= 'b0;
      trenc_pktlost_q <= 'b0;
      //trenc_pktlost_r <= 'b0;
    end 
    else begin
      trenc_started_q <= trenc_started;
      trenc_pktlost_q <= trenc_pktlost_i;
      //trenc_pktlost_r <= trenc_pktlost_q;
    end 
  end 

  assign trenc_started_lock = trenc_started & ~trenc_started_q;

  /*
   * FSM state:
   * IDLE   :initial state
   * START  :first instruction
   * TRACING:Tracing instruction
   */

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
     if(!trenc_rstn_i) pkt_cs <= IDLE;
     else              pkt_cs <= pkt_ns;
  end

  always_comb begin
     pkt_ns = pkt_cs;
     case(pkt_cs)
        IDLE : begin
        	if(trenc_started_lock && trenc_reseted) pkt_ns = START;
          else pkt_ns = IDLE;
        end
        START:begin
          if(ivalid) pkt_ns = TRACING;
          else if(trenc_stoped || !trenc_reseted) pkt_ns = IDLE;
          else pkt_ns = START;
        end
        TRACING : begin
        	if(trenc_stoped || !trenc_reseted) pkt_ns = IDLE;
          else pkt_ns = TRACING;
        end
     endcase
  end
  
  
  assign tracing                 = ((pkt_cs == TRACING) || (pkt_ns == TRACING)) ? 1'b1 : 1'b0;
  assign trace_stop              = ((pkt_cs == TRACING) && (pkt_ns == IDLE))    ? 1'b1 : 1'b0;
  assign trace_start             = ((pkt_cs == IDLE   ) && (pkt_ns == START))   ? 1'b1 : 1'b0;
  assign trace_first_instruction = ((pkt_cs == START  ) && (pkt_ns == TRACING)) ? 1'b1 : 1'b0;
  
  assign trace_first_inst        = trace_first_instruction || trenc_pktlost_q;
  //assign trace_first_inst        = trace_first_instruction;
  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      trace_stop_q    <= 'b0;
      trace_stop_r    <= 'b0;
      tracing_q       <= 'b0;
    end else begin 
      trace_stop_q    <= trace_stop;
      trace_stop_r    <= trace_stop_q;
      tracing_q       <= tracing;
    end 
  end

  assign trace_work = tracing_q || tracing;


  logic [INST_WIDTH:0] trenc_qualified;
  logic [INST_WIDTH:0] trenc_qualified_next;
  logic [INST_WIDTH:0] trenc_qualified_first;
  logic [INST_WIDTH-1:0] slot_valid;
 

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      inst_number <= 3'd0;
    end 
    else begin
      if(inter_uop[3].ivalid&& inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
        inst_number <= 3'd4;
      end       
      else if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid) begin
        inst_number <= 3'd3;
      end 
      else if((inter_uop[2].ivalid && inter_uop[1].ivalid) || (inter_uop[1].ivalid && inter_uop[0].ivalid) || (inter_uop[2].ivalid && inter_uop[0].ivalid)) begin
      //else if(inter_uop[2].ivalid && inter_uop[1].ivalid) begin
        inst_number <= 3'd2;
      end 
      else if(inter_uop[2].ivalid || inter_uop[1].ivalid || inter_uop[0].ivalid) begin
      //else if(inter_uop[2].ivalid) begin
        inst_number <= 'd1;
      end
      else begin
        inst_number <= 'd0;
      end
    end 
  end


  
  always_comb begin
    if(trenc_pktlost_q) begin
      slot_valid =4'b1111;  
    end 
    else if (trace_stop_r || trace_stop_q) begin
      slot_valid =4'b1000;
    end 
    else begin
      case(inst_number)
        3'b000:slot_valid = 4'b0000;
        3'b001:slot_valid = 4'b1000;
        3'b010:slot_valid = 4'b1100;
        3'b011:slot_valid = 4'b1110;
        3'b100:slot_valid = 4'b1111;
        default:slot_valid = 4'b0000;
      endcase
    end 
  end 



  for (genvar w_filter = 0; w_filter < INST_WIDTH+1; w_filter = w_filter+1) begin:gen_filter 
    trenc_filter inst_trenc_filter(
      .inter_uop              	(interface_uop_slot[w_filter+1]) ,
      .trenc_start_i            (trace_start)                    ,
      //.trenc_clk_i              (trenc_gclk_i)                   ,
      //.trenc_rst_i              (trenc_rstn_i)                   ,
      //.trenc_filter_i         	(trenc_filter_i)                 , 
      //.trenc_filaddr0h_i      	(trenc_filaddr0h_i)              ,  
      //.trenc_filaddr0l_i      	(trenc_filaddr0l_i)              , 
      //.trenc_filaddr1h_i      	(trenc_filaddr1h_i)              , 
      //.trenc_filaddr1l_i      	(trenc_filaddr1l_i)              , 
      .trenc_qualified_o      	(trenc_qualified[w_filter])      , 
      .trenc_qualified_first_o	(trenc_qualified_first[w_filter]) 
    ); 
  end

  always_comb begin
    if(trace_stop) begin
      trenc_qualified_next [0] = trenc_qualified[0];
      trenc_qualified_next [1] = trenc_qualified[1];
      trenc_qualified_next [2] = trenc_qualified[2];
      trenc_qualified_next [3] = trenc_qualified[3];
      trenc_qualified_next [4] = 'b1;
    end 
    else begin
      for(int i = 0; i<INST_WIDTH+1; i=i+1) begin
        trenc_qualified_next[i] = trenc_qualified[i];  
      end 
    end 
  end

  logic  [COUNT_WIDTH-1:0] count;  
  logic  count_valid;
  //assign count_valid = |inst_number;


  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      count_valid <= 'd0;
    end 
    else begin
      if(inter_uop[3].ivalid && inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid && inter_uop[0].itype != 'd1 &&  inter_uop[0].iretire != 'd0 && inter_uop[1].itype != 'd1 &&  inter_uop[1].iretire != 'd0) begin
       count_valid <= 'd1;
      end       
      else if(inter_uop[2].ivalid && inter_uop[1].ivalid && inter_uop[0].ivalid && inter_uop[0].itype != 'd1 &&  inter_uop[0].iretire != 'd0 && inter_uop[1].itype != 'd1 &&  inter_uop[1].iretire != 'd0) begin
        count_valid <= 'd1;
      end 
      else if((inter_uop[2].ivalid && inter_uop[1].ivalid) || (inter_uop[1].ivalid && inter_uop[0].ivalid && inter_uop[0].itype != 'd1 &&  inter_uop[0].iretire != 'd0  && inter_uop[1].itype != 'd1 &&  inter_uop[1].iretire != 'd0) || (inter_uop[2].ivalid && inter_uop[0].ivalid && inter_uop[0].itype != 'd1 &&  inter_uop[0].iretire != 'd0  && inter_uop[2].itype != 'd1 &&inter_uop[2].iretire != 'd0)) begin
        count_valid <= 3'd1;
      end 
      else if( (inter_uop[2].ivalid && inter_uop[2].itype != 'd1 &&  inter_uop[2].iretire != 'd0) ||(inter_uop[1].ivalid && inter_uop[1].itype != 'd1 &&  inter_uop[1].iretire != 'd0)||(inter_uop[0].ivalid && inter_uop[0].itype != 'd1 &&  inter_uop[0].iretire != 'd0) ) begin
        count_valid <= 'd1;
      end
      else begin
        count_valid <= 'd0;
      end
    end 
  end

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i )  begin
    if(!trenc_rstn_i) begin
    	count <= 16'b0;
    end 
    else begin
      if(!trenc_started || |resync ) begin 
        count <= 16'b0;
    	end 
      else if(count_valid) begin
    		count <= count+1'b1;
    	end 
    end 
  end


   

  logic [INST_WIDTH-1:0]                             ppccd;
  logic [INST_WIDTH-1:0]                          ppccd_br;
  logic [INST_WIDTH-1:0]                            pktvld;
  logic [INST_WIDTH-1:0]                          pktvld_q;
  logic [INST_WIDTH-1:0]                      trenc_brtken;
  logic [INST_WIDTH-1:0]                     trenc_brvalid;
  logic [INST_WIDTH-1:0]                  interrupt_status;   
  logic [INST_WIDTH-1:0]                       tval_status;
  logic [INST_WIDTH-1:0]                     ecause_status;
  logic [INST_WIDTH-1:0]                         addr_calc;
  logic [IADDRESS_WIDTH-1:0]       iaddr      [INST_WIDTH];  
  //logic [IADDRESS_WIDTH-1:0]       iaddr_q    [INST_WIDTH];
  logic [IADDRESS_WIDTH-1:0]       diff_iaddr [INST_WIDTH];
  logic [5:0]                      diff_len   [INST_WIDTH];
  logic [5:0]                      iaddr_len  [INST_WIDTH];
  pkt_format_t                    pkt_fmt     [INST_WIDTH];
  pkt_sync_sformat_t              sync_sfmt   [INST_WIDTH];
  qual_status_t                   qual_status [INST_WIDTH];
  pkt_thaddr_sformat_t            thaddr_sfmt [INST_WIDTH];
  logic [INST_WIDTH-1:0]                            notify;
  logic [INST_WIDTH-1:0]                          updiscon;

/*
  always @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin 
    if (!trenc_rstn_i) begin
      for (int i=0; i < INST_WIDTH; i++) iaddr_q[i] <= {IADDRESS_WIDTH{1'b0}};
    end 
    else begin 
      for (int i=0; i < INST_WIDTH; i++) begin	
        if(interface_uop_slot[i].ivalid)  iaddr_q[i] <= interface_uop_slot[i+1].iaddr;
      end
    end 
  end 
*/

  always_comb begin 
    if(trace_first_inst) begin
      ppccd[0]=1'b0;
      for (int w = 1;w < INST_WIDTH; w=w+1) begin
        if ((interface_uop_slot [w+1].priv != interface_uop_slot[w].priv) || (interface_uop_slot[w+1].cont[3:0] != interface_uop_slot[w].cont[3:0]) || (interface_uop_slot[w+1].cont[19:4] != interface_uop_slot[w].cont[19:4])
        && interface_uop_slot[w].ivalid && interface_uop_slot[w+1].ivalid  && slot_valid[w]) begin
          ppccd[w] = 'b1;  
        end 
        else begin 
          ppccd[w] = 'b0;
        end
      end
    end else begin
      for (int w = 0;w < INST_WIDTH; w=w+1) begin
        if ((interface_uop_slot [w+1].priv != interface_uop_slot[w].priv) || (interface_uop_slot[w+1].cont[3:0] != interface_uop_slot[w].cont[3:0]) || (interface_uop_slot[w+1].cont[19:4] != interface_uop_slot[w].cont[19:4])
        && interface_uop_slot[w].ivalid && interface_uop_slot[w+1].ivalid  && slot_valid[w]) begin
          ppccd[w] = 'b1;  
        end 
        else begin 
          ppccd[w] = 'b0;
        end
      end
    end 
  end 

  always_comb begin
    if(trace_stop_r || trace_stop_q) begin
      ppccd_br[3] = 'b0; 
      for(int w = 0; w<INST_WIDTH-1; w=w+1) begin
        if ((interface_uop_slot [w+1].priv != interface_uop_slot[w+2].priv) || (interface_uop_slot[w+1].cont[3:0] != interface_uop_slot[w+2].cont[3:0]) 
          || (interface_uop_slot[w+1].cont[19:4] != interface_uop_slot[w+2].cont[19:4])) begin
          ppccd_br[w] = 'b1;  
        end 
        else begin 
          ppccd_br[w] = 'b0;
        end  
      end  
    end 
    else begin
      for(int w = 0; w<INST_WIDTH; w=w+1) begin
        if ((interface_uop_slot [w+1].priv != interface_uop_slot[w+2].priv) || (interface_uop_slot[w+1].cont[3:0] != interface_uop_slot[w+2].cont[3:0]) 
          || (interface_uop_slot[w+1].cont[19:4] != interface_uop_slot[w+2].cont[19:4])) begin
          ppccd_br[w] = 'b1;  
        end 
        else begin 
          ppccd_br[w] = 'b0;
        end  
      end 
    end 
  end 
 
 
  always_comb begin
    for(int w_format = 0 ; w_format < INST_WIDTH ; w_format = w_format +1) begin
      trenc_brtken[w_format]     = 'b0;
      trenc_brvalid[w_format]    = 'b0;
      //if((interface_uop_slot[w_format+1].itype == 'd4 || interface_uop_slot[w_format+1].itype == 'd5 )&& slot_valid[w_format] && interface_uop_slot[w_format+1].ivalid == 'b1) begin //branch?
      if((interface_uop_slot[w_format+1].itype == 'd4 || interface_uop_slot[w_format+1].itype == 'd5 )&& slot_valid[w_format] && trace_work && interface_uop_slot[w_format+1].ivalid == 'b1) begin //branch?
        if((( interface_uop_slot[w_format+1].itype  == 'd1 || interface_uop_slot[w_format+1].itype  == 'd2) && interface_uop_slot[w_format+1].iretire=='d0) 
           && interface_uop_slot[w_format+1].ivalid == 'd1 && interface_uop_slot[w_format+1].ivalid == 'd1) begin
          trenc_brvalid[w_format]    = 'b0;
        end else begin
          trenc_brvalid[w_format]    = 'b1;
          if(interface_uop_slot[w_format+1].itype == 'd4) begin
            trenc_brtken[w_format]   = 1'b0;
          end else if(interface_uop_slot[w_format+1].itype == 'd5) begin
            trenc_brtken[w_format]   = 1'b1;
          end 
        end
      end 
    end 
  end

  logic [4:0]             brcnt_d,brcnt_q;
  logic [30:0]            brmap_d,brmap_q;
  logic [30:0]            brmap_remained [INST_WIDTH];
  logic [INST_WIDTH-1:0]  branch_map_empty;
  logic [INST_WIDTH-1:0]  trenc_brmap_flush;

  logic [4:0]  brcnt [INST_WIDTH];
  logic [30:0] brmap [INST_WIDTH];
  logic [INST_WIDTH-1:0] rpt_br;
  //logic [INST_WIDTH-1:0] rpt;
  
  always_comb begin
    for(int i =0;i<INST_WIDTH;i=i+1) begin
      brcnt[i] = brcnt_d;
      brmap[i] = brmap_d;
      brmap_remained[i] = 31'b0;
    end 
    if(|trenc_brmap_flush) begin
      if(trenc_brmap_flush == 4'b0001) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  brcnt[1]+trenc_brvalid[2];
        brcnt[3] =  brcnt[2]+trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] = trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] = trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] = trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] = trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q | brmap_remained[0];
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap[1]| brmap_remained[2];
        brmap[3] =  brmap[2]| brmap_remained[3];
      end
      else if(trenc_brmap_flush == 4'b0010) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  brcnt[0]+trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  brcnt[2] + trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] = trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] = trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] = trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] = trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap[2] | brmap_remained[3];
      end
      else if(trenc_brmap_flush == 4'b0100)  begin
        brcnt[0] =  brcnt_q  +trenc_brvalid[0];
        brcnt[1] =  brcnt[0] +trenc_brvalid[1];
        brcnt[2] =  brcnt[1] +trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] = trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] = trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] = trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] = trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap[1] | brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1000) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  brcnt[0] + trenc_brvalid[1];
        brcnt[2] =  brcnt[1] + trenc_brvalid[2];
        brcnt[3] =  brcnt[2] + trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] = trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] = trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] = trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] = trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap[1] | brmap_remained[2];
        brmap[3] =  brmap[2] | brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b0011) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  brcnt[2]+ trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] = trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] = trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] = trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] = trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;
        
        brmap[0] =  brmap_q | brmap_remained[0];
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap[2] | brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b0101) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  brcnt[1]+trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap[1] | brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1001) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  brcnt[1]+trenc_brvalid[2];
        brcnt[3] =  brcnt[2]+trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap[1] | brmap_remained[2];
        brmap[3] =  brmap[2] | brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b0110) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  brcnt[0] + trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q |  brmap_remained[0] ;
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1010) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  brcnt[0] + trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  brcnt[2] + trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap[2] | brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1100) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  brcnt[0] + trenc_brvalid[1];
        brcnt[2] =  brcnt[1] + trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];

        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap[1] | brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b0111) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q | brmap_remained[0] ;
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1011) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  brcnt[2] + trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q | brmap_remained[0] ;
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap[2]| brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1101) begin
        brcnt[0] =  brcnt_q+trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  brcnt[1] + trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q | brmap_remained[0] ;
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap[1]| brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else if(trenc_brmap_flush == 4'b1110) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  brcnt[0] + trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap[0] | brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end
      else if(trenc_brmap_flush == 4'b1111) begin
        brcnt[0] =  brcnt_q  + trenc_brvalid[0];
        brcnt[1] =  trenc_brvalid[1];
        brcnt[2] =  trenc_brvalid[2];
        brcnt[3] =  trenc_brvalid[3];
        
        brmap_remained[0][brcnt[0]-1] =  trenc_brvalid[0]? ~ trenc_brtken[0]:1'b0;
        brmap_remained[1][brcnt[1]-1] =  trenc_brvalid[1]? ~ trenc_brtken[1]:1'b0;
        brmap_remained[2][brcnt[2]-1] =  trenc_brvalid[2]? ~ trenc_brtken[2]:1'b0;
        brmap_remained[3][brcnt[3]-1] =  trenc_brvalid[3]? ~ trenc_brtken[3]:1'b0;

        brmap[0] =  brmap_q  | brmap_remained[0];
        brmap[1] =  brmap_remained[1];
        brmap[2] =  brmap_remained[2];
        brmap[3] =  brmap_remained[3];
      end 
      else begin
        for(int j = 0;j<INST_WIDTH;j=j+1) begin
          brcnt[j] =  5'b0;
          brmap_remained[j] = 31'b0;
          brmap[j] =  31'b0;
        end 
      end 
    end 
  end

  always_comb begin 
    brmap_d = brmap_q;
    brcnt_d = brcnt_q;
    for (int i=0; i < INST_WIDTH ; i++) begin 
      if (trenc_brvalid[i]) begin
        brcnt_d = brcnt_d + 1;
        if(brcnt_d == 'd31) begin
          brmap_d[30] = ~ trenc_brtken[i];
        end 
        else begin
          brmap_d[brcnt_d-1] = ~ trenc_brtken[i];
        end 
      end    
    end    
  end
  
  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      brmap_q <= 'b0;
      brcnt_q <= 'b0;
    end
    else if(trenc_pktlost_i) begin
      brmap_q <= 'b0;
      brcnt_q <= 'b0;      
    end 
    else if (|trenc_brmap_flush) begin
      //if(trenc_brmap_flush == 4'b1000 || trenc_brmap_flush == 4'b1100 || trenc_brmap_flush == 4'b1110 || trenc_brmap_flush == 4'b1111 ) begin 
      if(trenc_brmap_flush[3] == 1'b1) begin 
        brmap_q <= 'b0;
        brcnt_q <= 'b0;
      end 
      else begin
        brmap_q <= brmap[3];
        brcnt_q <= brcnt[3];        
      end
    end 
    else begin
      brmap_q <= brmap_d;
      brcnt_q <= brcnt_d;
    end
  end

  logic [1:0] start_slot,stop_slot;
  always_comb begin
    start_slot = 2'd0;
    if (trace_first_inst) begin
      if(interface_uop_slot[1].ivalid)     start_slot = 2'd0; 
      else if(interface_uop_slot[2].ivalid)start_slot = 2'd1;
      else if(interface_uop_slot[3].ivalid)start_slot = 2'd2;
      else if(interface_uop_slot[4].ivalid)start_slot = 2'd3;
      else start_slot = 2'd0;
    end 
  end 
/*
  always_comb begin
    stop_slot = 3'd0;
    if(trace_stop_r || trace_stop_q) begin
      if (interface_uop_slot[4].ivalid && interface_uop_slot[4].iretire != 'd0 && interface_uop_slot[4].itype != 'd1 ) stop_slot = 3'd3;
      else if(interface_uop_slot[3].ivalid && interface_uop_slot[3].iretire != 'd0 && interface_uop_slot[3].itype != 'd1 ) stop_slot = 3'd2;
      else if(interface_uop_slot[2].ivalid && interface_uop_slot[2].iretire != 'd0 && interface_uop_slot[2].itype != 'd1 ) stop_slot = 3'd1;
      else if(interface_uop_slot[1].ivalid && interface_uop_slot[1].iretire != 'd0 && interface_uop_slot[1].itype != 'd1 ) stop_slot = 3'd0;
      else stop_slot = 3'd0;
    end 
  end
*/
  always_comb begin
    stop_slot = 2'd0;
    if(trace_stop_r || trace_stop_q) begin
      if (interface_uop_slot[4].ivalid )     stop_slot = 2'd3;
      else if(interface_uop_slot[3].ivalid ) stop_slot = 2'd2;
      else if(interface_uop_slot[2].ivalid ) stop_slot = 2'd1;
      else if(interface_uop_slot[1].ivalid ) stop_slot = 2'd0;
      else stop_slot = 2'd0;
    end 
  end 


  
  always_comb begin
    for(int w_flush = 0; w_flush<INST_WIDTH; w_flush= w_flush+1) begin
      if (pkt_fmt[w_flush] == FORMAT1 || (pkt_fmt[w_flush] == FORMAT3 && sync_sfmt[w_flush] == SF_START) || (pkt_fmt[w_flush] == FORMAT3 && sync_sfmt[w_flush] == SF_TRAP)) begin
        trenc_brmap_flush[w_flush] ='b1;
      end else begin
        trenc_brmap_flush[w_flush] ='b0;
      end
    end
  end 

  assign branch_map_empty[0] = (brcnt_q + trenc_brvalid[0] == 'd0) ? 1'b1:1'b0;
  
  always_comb begin
    if(trenc_brmap_flush[0] == 1'b1) begin
      if(trenc_brvalid[1]) branch_map_empty[1] = 1'b0;
      else branch_map_empty[1] = 1'b1;
    end else begin
      if(brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] == 'd0) branch_map_empty[1] = 1'b1;
      else branch_map_empty[1] = 1'b0;
    end 
  end


  always_comb begin
    if(trenc_brmap_flush[1] == 1'b1) begin
      if(trenc_brvalid[2] == 'd0) branch_map_empty[2] = 1'b1;
      else branch_map_empty[2] = 1'b0;      
    end else if(trenc_brmap_flush[0] == 1'b1) begin
      if(trenc_brvalid[1] + trenc_brvalid[2] == 'd0) branch_map_empty[2] = 1'b1;
      else branch_map_empty[2] = 1'b0;         
    end else begin
      if(brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] + trenc_brvalid[2] == 'd0) branch_map_empty[2] = 1'b1;
      else branch_map_empty[2] = 1'b0;
    end
  end


  always_comb begin
    if(trenc_brmap_flush[2] == 1'b1) begin
     if(trenc_brvalid[3]== 'd0) branch_map_empty[3] = 1'b1;
     else branch_map_empty[3] = 1'b0;  
    end else if(trenc_brmap_flush[1] == 1'b1) begin
      if(trenc_brvalid[2] + trenc_brvalid[3] == 'd0) branch_map_empty[3] = 1'b1;
      else branch_map_empty[3] = 1'b0;         
    end else if(trenc_brmap_flush[0] == 1'b1 )begin
      if(trenc_brvalid[1] + trenc_brvalid[2] + trenc_brvalid[3] == 'd0) branch_map_empty[3] = 1'b1;
      else branch_map_empty[3] = 1'b0;  
    end else begin
      if(brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] + trenc_brvalid[2] + trenc_brvalid[3]== 'd0) branch_map_empty[3] = 1'b1;
      else branch_map_empty[3] = 1'b0;      
    end 
  end

 //change rpt_br logic  
  assign rpt_br[0] = (brcnt_q + trenc_brvalid[0] == 'd31) ? 1'b1:1'b0;
  
  always_comb begin
    rpt_br[1] = 1'b0;
    if(trenc_brmap_flush[0] == 1'b1)  rpt_br[1] = 1'b0;
    else if (brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] == 'd31) rpt_br[1] = 1'b1;
  end 
  
  always_comb begin
    rpt_br[2] = 'b0;
    if(trenc_brmap_flush[0] == 1'b1 || trenc_brmap_flush[1] == 1'b1) rpt_br[2] = 1'b0;
    else if(brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] + trenc_brvalid[2] == 'd31) rpt_br[2] = 1'b1;       
  end 

  always_comb begin
    rpt_br[3] = 'b0;
    if(|trenc_brmap_flush[2:0] == 1'b1) rpt_br[3] = 1'b0;
    else if(brcnt_q + trenc_brvalid[0] + trenc_brvalid[1] + trenc_brvalid[2] + trenc_brvalid[3]== 'd31) rpt_br[3] = 1'b1;       
  end 


  logic [1:0] count_slot;
  
  always_comb begin
    case(slot_valid) 
      4'b1111:count_slot=2'b00; //0 
      4'b1110:count_slot=2'b01; //1
      4'b1100:count_slot=2'b10; //2
      4'b1000:count_slot=2'b11; //3
      default:count_slot=2'b00;
    endcase 
  end 

  always_comb begin
    for (int  w_format = 0 ; w_format < INST_WIDTH ; w_format = w_format +1) begin
      pktvld[w_format]              = 'b0;
      interrupt_status[w_format]    = 'b0;
      tval_status[w_format]         = 'b0;
      ecause_status[w_format]       = 'b0;
      addr_calc[w_format]           = 'b0;
      resync[w_format]              = 'b0;
      qual_status[w_format]         = NO_CHANGE;  
      thaddr_sfmt[w_format]         = SF_THADDR0;    
      pkt_fmt[w_format]             = FORMAT3;
      sync_sfmt[w_format]           = SF_SUPPORT;
      notify[w_format]              = 1'b0;
      updiscon[w_format]            = 1'b0;
      excp_has_reported[w_format]   = 1'b0;
      if(trace_first_inst && interface_uop_slot[w_format+CURRENT_SLOT].ivalid && w_format == start_slot) begin
        pkt_fmt[w_format]                = FORMAT3;
    	  sync_sfmt[w_format]              = SF_START;
        pktvld[w_format]                 = 1'b1;      
        qual_status[w_format]            = NO_CHANGE;  
        resync[w_format]                 = 1'b1;
        addr_calc[w_format]              = 1'b0;
      end else if(trace_stop_r && w_format == stop_slot  && pktvld_q[3] != 'b1) begin
        if(!branch_map_empty[w_format] || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5) begin // has branch to report? 
    	    pkt_fmt[w_format]              = FORMAT1;
    	    pktvld[w_format]               = 1'b1; 
          sync_sfmt[w_format]            = SF_BRA_ADDR;
          notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
          updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
          addr_calc[w_format]            = 1'b1;
    	  end else begin
    	    pkt_fmt[w_format]              = FORMAT2;
    	    sync_sfmt[w_format]            = SF_ADDR;
    	    pktvld[w_format]               = 1'b1;
          notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
          updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
          addr_calc[w_format]            = 1'b1;
        end  
      end else begin
        if(interface_uop_slot[w_format+CURRENT_SLOT].ivalid && trenc_qualified[w_format] && trace_work && slot_valid[w_format]) begin
          if((interface_uop_slot[w_format+PREVIOUS_SLOT].itype =='d1 || interface_uop_slot[w_format+PREVIOUS_SLOT].itype =='d2)&& interface_uop_slot[w_format+PREVIOUS_SLOT].ivalid) begin //exception previous? 
    	      if((interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd1 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd2) && interface_uop_slot[w_format+CURRENT_SLOT].iretire == 'd0) begin //exc_only?
    	        pkt_fmt[w_format]              = FORMAT3;
    	        sync_sfmt[w_format]            = SF_TRAP;       //Trap 
    	       	pktvld[w_format]               = 1'b1;      
    	        qual_status[w_format]          = NO_CHANGE;  
    	       	thaddr_sfmt[w_format]          = SF_THADDR0;    //Thaddr = 0
    	       	resync[w_format]               = 1;             // need change
              interrupt_status[w_format]     = 0;             // indictate previous 
              tval_status[w_format]          = 1'b0;
              ecause_status[w_format]        = 1'b0;
              addr_calc[w_format]            = 1'b0;
    	      end else if(reported[w_format+PREVIOUS_SLOT]) begin             //reported 
    	       	pkt_fmt[w_format]              = FORMAT3;
    	        sync_sfmt[w_format]            = SF_START;
    	       	pktvld[w_format]               = 1'b1;      
    	        qual_status[w_format]          = NO_CHANGE;     //START
    	        resync[w_format]               = 1;
              addr_calc[w_format]            = 1'b0;
    	      end else begin
    	        pkt_fmt[w_format]              = FORMAT3;
    	        sync_sfmt[w_format]            = SF_TRAP;
    	       	pktvld[w_format]               = 1'b1;      
    	        qual_status[w_format]          = NO_CHANGE;     //TRAP
    	       	thaddr_sfmt[w_format]          = SF_THADDR1;    //Thaddr = 1
    	       	resync[w_format]               = 1;		
              interrupt_status[w_format]     = 0;             // 0 indictate previous
              tval_status[w_format]          = 1'b0;
              ecause_status[w_format]        = 1'b0;
              addr_calc[w_format]            = 1'b0;
    	      end 
    	    end else if(trenc_qualified_first[w_format] || ppccd[w_format] || ((count > trenc_expire_time_i && w_format == count_slot))) begin //ppcd or count>max_resync
    	        pkt_fmt[w_format]              = FORMAT3;
    	        sync_sfmt[w_format]            = SF_START;
    	       	pktvld[w_format]               = 1'b1;      
    	        qual_status[w_format]          = NO_CHANGE;     //START
    	       	resync[w_format]               = 1;
              addr_calc[w_format]            = 1'b0;
    	    end else if((interface_uop_slot[w_format+PREVIOUS_SLOT].itype =='d6 || interface_uop_slot[w_format+PREVIOUS_SLOT].itype =='d3) && interface_uop_slot[w_format+PREVIOUS_SLOT].ivalid == 'b1 ) begin  //updiscon previous 
    	      if((interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd1 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd2)  && interface_uop_slot[w_format+CURRENT_SLOT].iretire == 'd0)  begin//exc_only		
    	        pkt_fmt[w_format]              = FORMAT3;
    	        sync_sfmt[w_format]            = SF_TRAP;
    	       	pktvld[w_format]               = 1'b1;      
    	        qual_status[w_format]          = NO_CHANGE;           //Trap
    	       	thaddr_sfmt[w_format]          = SF_THADDR0;          //Thaddr = 0
    	       	resync[w_format]               = 1;
              interrupt_status[w_format]     = 1;   // 1 indictate current
              tval_status[w_format]          = 1'b1;
              ecause_status[w_format]        = 1'b1;
              excp_has_reported[w_format]    = 1'b1;
              addr_calc[w_format]            = 1'b0;
    	      end else begin
    	        if(!branch_map_empty[w_format] || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5 ) begin // has branch to report? 
    	    	    pkt_fmt[w_format]              = FORMAT1;
    	    	    pktvld[w_format]               = 1'b1; 
                notify[w_format]               = interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
    	    	    sync_sfmt[w_format]            = SF_BRA_ADDR;
                addr_calc[w_format]            = 1'b0;
    	        end else begin
    	    	    pkt_fmt[w_format]              = FORMAT2;
    	    	    sync_sfmt[w_format]            = SF_ADDR;
    	       		pktvld[w_format]               = 1'b1; 
                notify[w_format]               = interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                addr_calc[w_format]            = 1'b0;
    	        end 
    	      end 
    	      end else if((((count == trenc_expire_time_i) && w_format  == 'd3)  && !branch_map_empty[w_format]) || ((interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd2 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd1)  && interface_uop_slot[w_format+CURRENT_SLOT].iretire != 'd0) ) begin // current instr is resync_br or er_n 
            if(((count == trenc_expire_time_i) && w_format  == 'd3)  && !branch_map_empty[w_format]) begin
              if(!branch_map_empty[w_format] || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5) begin // has branch to report? 
    	    	      pkt_fmt[w_format]              = FORMAT1;
    	    	      pktvld[w_format]               = 1'b1; 
    	    	      sync_sfmt[w_format]            = SF_BRA_ADDR;
                  notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  addr_calc[w_format]            = 1'b0;
    	        end else begin
    	    	      pkt_fmt[w_format]              = FORMAT2;
    	    	      sync_sfmt[w_format]            = SF_ADDR;
    	       		  pktvld[w_format]               = 1'b1;
                  notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  addr_calc[w_format]            = 1'b0;
    	        end
            end 
            else begin
              if(!branch_map_empty[w_format] || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5) begin // has branch to report? 
    	    	      pkt_fmt[w_format]              = FORMAT1;
    	    	      pktvld[w_format]               = 1'b1; 
    	    	      sync_sfmt[w_format]            = SF_BRA_ADDR;
                  notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  updiscon[w_format]             = interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  addr_calc[w_format]            = 1'b0;
    	        end else begin
    	    	      pkt_fmt[w_format]              = FORMAT2;
    	    	      sync_sfmt[w_format]            = SF_ADDR;
    	       		  pktvld[w_format]               = 1'b1;
                  notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  updiscon[w_format]             = interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                  addr_calc[w_format]            = 1'b0;
    	        end
            end 
            end else if ((((interface_uop_slot[w_format+NEXT_SLOT].itype == 'd1 || interface_uop_slot[w_format+NEXT_SLOT].itype == 'd2)  && interface_uop_slot[w_format+NEXT_SLOT].iretire == 'd0) && interface_uop_slot[w_format+NEXT_SLOT].ivalid == 'b1) || (ppccd_br[w_format] && !branch_map_empty[w_format] ) || !trenc_qualified_next[w_format+CURRENT_SLOT]) begin //next instr is exc_only or ppccd or unqualitifed 
    	      if(!branch_map_empty[w_format]  || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5) begin // has branch to report? 
    	    	    pkt_fmt[w_format]              = FORMAT1;
    	    	    pktvld[w_format]               = 1'b1; 
    	    	    sync_sfmt[w_format]            = SF_BRA_ADDR;
                notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                addr_calc[w_format]            = 1'b1;
    	      end else begin
    	    	    pkt_fmt[w_format]              = FORMAT2;
    	    	    sync_sfmt[w_format]            = SF_ADDR;
    	       		pktvld[w_format]               = 1'b1;
                notify[w_format]               = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                updiscon[w_format]             = ~interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
                addr_calc[w_format]            = 1'b1;
    	      end  
          end else if(rpt_br[w_format] && (interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd4 || interface_uop_slot[w_format+CURRENT_SLOT].itype == 'd5)) begin  //rpt_br? report branches due to full branch map 
    	      pkt_fmt[w_format]              = FORMAT1;// need to report branch
    	      sync_sfmt[w_format]            = SF_BRA_NADDR;
    	     	pktvld[w_format]               = 1'b1;
            notify[w_format]               = interface_uop_slot[w_format+CURRENT_SLOT].iaddr[38];
            addr_calc[w_format]            = 1'b0;
          end 
        end
      end 
    end 
  end 

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      pktvld_q <= 'b0;
    end 
    else begin
      pktvld_q <= pktvld;
    end 
  end 



  

  always_comb begin
    if(trace_stop_q || trace_stop_r ) begin
      for (int w = 0;w<INST_WIDTH;w=w+1) begin
        case(stop_slot)
          2'd0:begin
          	iaddr[w]     = 'd0;
			      iaddr_len[w] = 'd0;     
          end 
          2'd1:begin
           iaddr[w]      = addr_calc[w]?(interface_uop_slot[2].iretire==1'b0 ?interface_uop_slot[2].iaddr:interface_uop_slot[2].iaddr + interface_uop_slot[2].iretire - (interface_uop_slot[2].ilastsize?'h2:'h1)):interface_uop_slot[2].iaddr;
            iaddr_len[w] = IADDR_LEN;     
          end
          2'd2:begin
			      iaddr[w]     = addr_calc[w]?(interface_uop_slot[3].iretire==1'b0 ?interface_uop_slot[3].iaddr:interface_uop_slot[3].iaddr + interface_uop_slot[3].iretire - (interface_uop_slot[3].ilastsize?'h2:'h1)):interface_uop_slot[3].iaddr;
iaddr_len[w] = IADDR_LEN;     
          end 
          2'd3:begin
			      iaddr[w]     = addr_calc[w]?(interface_uop_slot[4].iretire==1'b0 ?interface_uop_slot[4].iaddr:interface_uop_slot[4].iaddr + interface_uop_slot[4].iretire - (interface_uop_slot[4].ilastsize?'h2:'h1)):interface_uop_slot[4].iaddr;
            iaddr_len[w] = IADDR_LEN;     
          end
          default:begin
			      iaddr[w]     = addr_calc[w]?(interface_uop_slot[4].iretire==1'b0 ?interface_uop_slot[4].iaddr:interface_uop_slot[4].iaddr + interface_uop_slot[4].iretire - (interface_uop_slot[4].ilastsize?'h2:'h1)):interface_uop_slot[4].iaddr;
            iaddr_len[w] = IADDR_LEN;    
          end 
        endcase 
      end 
    end else begin 
	    for (int w = 0;w<INST_WIDTH;w=w+1) begin
		    //if (pkt_fmt[w] == FORMAT3) begin
		  	//  iaddr[w]     = addr_calc[w]?(interface_uop_slot[w+1].iretire==1'b0 ?interface_uop_slot[w+1].iaddr:interface_uop_slot[w+1].iaddr + interface_uop_slot[w+1].iretire - (interface_uop_slot[w+1].ilastsize?'h2:'h1)):interface_uop_slot[w+1].iaddr;
        //  iaddr_len[w] = IADDR_LEN; 
		    //end 
        //else if(trenc_mode_i == FULL_MODE) begin // trenc_mode_i == DIFF_MODE
        // iaddr[w]     = addr_calc[w]?(interface_uop_slot[w+1].iretire==1'b0 ?interface_uop_slot[w+1].iaddr:interface_uop_slot[w+1].iaddr + interface_uop_slot[w+1].iretire - (interface_uop_slot[w+1].ilastsize?'h2:'h1)):interface_uop_slot[w+1].iaddr;
		  	//  iaddr_len[w] = IADDR_LEN; 
        //end 
        //else if(trenc_mode_i == DIFF_MODE) begin
        //  iaddr[w]     = diff_iaddr[w];
		  	//  iaddr_len[w] = IADDR_LEN; 
        //end 
        //else begin
		  	  iaddr[w]     = addr_calc[w]?(interface_uop_slot[w+1].iretire==1'b0 ?interface_uop_slot[w+1].iaddr:interface_uop_slot[w+1].iaddr + interface_uop_slot[w+1].iretire - (interface_uop_slot[w+1].ilastsize?'h2:'h1)):interface_uop_slot[w+1].iaddr;
		  	  iaddr_len[w] = IADDR_LEN; 
        //end 
	    end 
    end 
  end   
/*   
  always_comb begin
    for (int w = 0;w<INST_WIDTH;w=w+1) begin
      diff_iaddr[w] = interface_uop_slot[w+1].iaddr-iaddr_q[w];
    end 
  end           
  always_comb begin
    for (int w = 0;w<INST_WIDTH;w=w+1) begin
      if(interface_uop_slot[w+1].iaddr >= interface_uop_slot[w].iaddr) diff_iaddr[w] = interface_uop_slot[w+1].iaddr -  interface_uop_slot[w].iaddr;
      else  diff_iaddr[w] = interface_uop_slot[w].iaddr -  interface_uop_slot[w+1].iaddr;
    end 
  end 
  */



  logic[PKTDATA_WIDTH-1:0]  pktlen        [INST_WIDTH];
  logic[PAYLOAD_LEN-1:0]    pktdat        [INST_WIDTH];
  logic[TVAL_LEN-1:0]       tval_addr     [INST_WIDTH];
  logic[ECAUSE_WIDTH-1:0]   ecause        [INST_WIDTH];
  logic[INST_WIDTH-1:0]     branch_filed;
  logic[INST_WIDTH-1:0]     interrupt;
 
  always_comb begin
    for (int w_pkt = 0 ; w_pkt < INST_WIDTH ; w_pkt = w_pkt+1) begin
      if(((interface_uop_slot[w_pkt+1].itype != 'd4 && interface_uop_slot[w_pkt+1].itype !='d5) || interface_uop_slot[w_pkt+1].itype == 'd4) && interface_uop_slot[w_pkt+1].ivalid)begin 
        branch_filed[w_pkt] = 1'b1;
      end else if (interface_uop_slot[w_pkt+1].itype == 'd5) begin
        branch_filed[w_pkt] = 1'b0;
      end else begin
        branch_filed[w_pkt] = 1'b1;
      end 
    end 
  end 

  always_comb begin
    for(int w_pkt = 0 ; w_pkt < INST_WIDTH ; w_pkt = w_pkt+1) begin
      if(interrupt_status[w_pkt]) begin       
       if(interface_uop_slot[w_pkt+1].itype == 'd2) begin
         interrupt[w_pkt]    = 1'b1;
       end else begin
         interrupt[w_pkt]    = 1'b0;
       end
      end else begin
       if(interface_uop_slot[w_pkt].itype == 'd2) begin
         interrupt[w_pkt]    = 1'b1;
       end else begin
         interrupt[w_pkt]    = 1'b0;
       end 
      end
    end 
  end 

  always_comb begin
    for(int w_pkt = 0 ; w_pkt < INST_WIDTH ; w_pkt = w_pkt+1) begin
      if(tval_status[w_pkt]) begin
        tval_addr[w_pkt] = interface_uop_slot[w_pkt+1].tval;
      end else begin
        tval_addr[w_pkt] = interface_uop_slot[w_pkt].tval;
      end 
    end
  end 
  
  always_comb begin
    for(int w_pkt = 0 ; w_pkt < INST_WIDTH ; w_pkt = w_pkt+1) begin
      if(ecause_status[w_pkt]) begin
        ecause[w_pkt] = interface_uop_slot[w_pkt+1].cause;
      end else begin
        ecause[w_pkt] = interface_uop_slot[w_pkt].cause;
      end 
    end
  end
  
  always_comb begin
    for (int w_pkt = 0 ; w_pkt < INST_WIDTH ; w_pkt = w_pkt+1) begin 
     pktlen[w_pkt] = 9'b0;
     pktdat[w_pkt] = {PAYLOAD_LEN{1'b0}};
     if(pktvld[w_pkt]) begin   
       case(pkt_fmt[w_pkt]) 
         FORMAT3 : begin
           case(sync_sfmt[w_pkt])
             SF_START : begin  
               pktlen[w_pkt] = FORMAT_LEN + SUBFORMAT_LEN + 1 + PRIV_LEN  + TIME_LEN +CONT_LEN +IADDR_LEN;
               pktdat[w_pkt] = {4'b1100,branch_filed[w_pkt],interface_uop_slot[w_pkt+1].priv,
               trenc_itime,
               interface_uop_slot[w_pkt+1].cont,
               iaddr[w_pkt]};
             end
             SF_TRAP : begin // format3 subformat 1
               if(!interrupt[w_pkt])  begin
                 pktlen[w_pkt] = FORMAT_LEN + SUBFORMAT_LEN + 1 + PRIV_LEN + TIME_LEN + CONT_LEN + ECAUSE_LEN + 2 + IADDR_LEN + TVAL_LEN;
                 pktdat[w_pkt] = {4'b1101,branch_filed[w_pkt],interface_uop_slot[w_pkt+1].priv,
                 trenc_itime,
                 interface_uop_slot[w_pkt+1].cont,  //84-87
                 ecause[w_pkt],     //78-83
                 interrupt[w_pkt],  //77
                 thaddr_sfmt[w_pkt],//76
                 iaddr[w_pkt],     //39-75
                 tval_addr[w_pkt]};//0-38
               end else begin
                 pktlen[w_pkt] = FORMAT_LEN + SUBFORMAT_LEN + 1 + PRIV_LEN + TIME_LEN + CONT_LEN + ECAUSE_LEN + 2 + IADDR_LEN;
                 pktdat[w_pkt] = {4'b1101,branch_filed[w_pkt],interface_uop_slot[w_pkt+1].priv,
                 trenc_itime,
                 interface_uop_slot[w_pkt+1].cont,//47-50
                 ecause[w_pkt],      //41-46
                 interrupt[w_pkt],   //40
                 thaddr_sfmt[w_pkt],  //39
                 iaddr[w_pkt]};    //0-38
               end  
             end
             default:begin
               pktlen[w_pkt] = 9'b0;
               pktdat[w_pkt] = {PAYLOAD_LEN{1'b0}};
             end 
           endcase
         end
         FORMAT2 : begin
           pktlen[w_pkt] = FORMAT_LEN + iaddr_len[w_pkt]+2;
           pktdat[w_pkt] = {2'b10,iaddr[w_pkt],notify[w_pkt],updiscon[w_pkt]};
         end
         FORMAT1 : begin 
           case(sync_sfmt[w_pkt])
             SF_BRA_ADDR : begin
               pktdat[w_pkt] = {2'b01,brcnt[w_pkt],brmap[w_pkt],iaddr[w_pkt],notify[w_pkt],updiscon[w_pkt]};
               pktlen[w_pkt] = FORMAT_LEN + BRANCH_LEN + 31 + iaddr_len[w_pkt]+2; 
             end  
             SF_BRA_NADDR : begin
               pktlen[w_pkt] = FORMAT_LEN +  BRANCH_LEN + BRMAP_LEN;
               pktdat[w_pkt] = {2'b01,5'b0,brmap[w_pkt]};
             end
             default:begin
               pktlen[w_pkt] = 9'b0;
               pktdat[w_pkt] = {PAYLOAD_LEN{1'b0}};
             end 
           endcase
         end     
       endcase
     end
   end 
  end 
 
  always_comb begin
    for(int w_out = 0;w_out<INST_WIDTH;w_out = w_out+1) begin
      trenc_pkt_o           [w_out] = pktdat            [w_out];
      trenc_pkt_vld_o       [w_out] = pktvld            [w_out];
      trenc_pkt_fmt_o       [w_out] = pkt_fmt           [w_out];
      trenc_sync_sfmt_o     [w_out] = sync_sfmt         [w_out];
      trenc_interrupt_o     [w_out] = interrupt         [w_out];
    end 
  end
  assign trenc_stop_o       = trace_stop_r;
 endmodule
