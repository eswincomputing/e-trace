// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
module trenc_top
  import trenc_pkg::*;
(
   // APB slave interface for register acess
  input  logic                       trenc_pclk_i                        ,
  input  logic                       trenc_prstn_i                       ,
  input  logic                       trenc_psel_i                        ,
  input  logic                       trenc_penable_i                     ,
  input  logic                       trenc_pwrite_i                      ,
  input  logic[APBAWIDTH-1:0]        trenc_paddr_i                       ,
  input  logic[APBDWIDTH-1:0]        trenc_pwdata_i                      ,
  output logic[APBDWIDTH-1:0]        trenc_prdata_o                      ,
  output logic                       trenc_pready_o                      ,
  output logic                       trenc_pslverr_o                     ,
  input  microop_t inter_uop_i       [INST_WIDTH-1]                      ,
  input  logic [1:0]                 trenc_core_id_i                     ,
  input  logic                       trenc_async_expt_vld_i              ,
  input  logic                       trenc_int_vld_i                     ,
  // side band signal
  input  logic                       trenc_clk_i                         ,
  input  logic                       trenc_rstn_i                        ,
  input  logic[TIME_WIDTH-1:0]       trenc_itime_i                       ,
  // ATB master interface to next level module
  input  logic                       trenc_atclk_i                       ,
  input  logic                       trenc_atrstn_i                      ,
  input  logic                       trenc_atready_i                     ,
  input  logic                       trenc_afvalid_i                     ,
  output logic[$clog2(ATBWIDTH)-4:0] trenc_atbyte_o                      ,
  output logic[ATBWIDTH-1:0]         trenc_atdata_o                      ,
  output logic[6:0]                  trenc_atid_o                        ,
  output logic                       trenc_atvalid_o                     ,
  output logic                       trenc_afready_o                 
);
  logic                     gclk                                         ; 
  logic 		                trenc_trctrl_enable                          ;
  logic 		                trenc_trctrl_start                           ;
  logic 		                trenc_trctrl_tscon                           ;
  logic 		                trenc_trctrl_compr                           ;
  logic 		                trenc_trctrl_tmode                           ;
  //logic[APBDWIDTH-1:0]      trenc_trctrl_tfilter                         ;
  //logic[APBDWIDTH-1:0]      trenc_tefilteraddr0l                         ;
  //logic[APBDWIDTH-1:0]      trenc_tefilteraddr0h                         ;
  //logic[APBDWIDTH-1:0]      trenc_tefilteraddr1l                         ;
  //logic[APBDWIDTH-1:0]      trenc_tefilteraddr1h                         ;
  //logic[SYNC_LEN-1:0]       trenc_tesync_data                            ;
  logic[TIME_WIDTH-1:0]     trenc_tetime                                 ;
  //logic 		                trenc_tesync                                 ;
  logic                     trenc_tecoder_mode                           ;
  logic                     trenc_pktlost                                ;
  logic[PKTDATA_LEN-1:0]    trenc_data      [INST_WIDTH]                 ;
  logic[PUSH_WIDTH-1:0]     trenc_fifo_data [INST_WIDTH]                 ;
  logic[PAYLOAD_LEN-1:0]    trenc_pkt       [INST_WIDTH]                 ;
  logic[PAYLOAD_LEN-1:0]    trenc_pkt_crossing[INST_WIDTH]               ;
  logic[INST_WIDTH-1:0]     trenc_pkt_vld                                ;
  logic                     trenc_empty                                  ;
  logic                     trenc_full                                   ;
  //logic                 trenc_atb_empty                              ;
  logic[PKTDATA_WIDTH-1:0]  trenc_data_len [INST_WIDTH]                  ;
  logic[INST_WIDTH-1:0]     trenc_data_vld                               ;
  logic[POP_WIDTH-1:0]      trenc_data_out                               ;
  logic[$clog2(DEPTH)-1:0]  trenc_rd_ptr                                 ;
  logic[$clog2(DEPTH)-1:0]  trenc_wr_ptr                                 ;
  logic                     trenc_fifo_aval                              ;
  logic                     trenc_data_aval                              ;
  logic                     trenc_buf_fetch                              ;
  logic                     atclk_i                                      ;
  logic[TIME_WIDTH-1:0]     itime                                        ;
  logic[INST_WIDTH-1:0]     interrupt                                    ;
  logic                     trenc_stop                                   ;


  pkt_format_t              pkt_fmt                   [INST_WIDTH]       ;
  pkt_sync_sformat_t        sync_sfmt                 [INST_WIDTH]       ;

  assign atclk_i = trenc_atclk_i;
  assign gclk    = trenc_clk_i;   

  always_ff@(posedge gclk or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      itime <= {TIME_WIDTH{1'b0}};  
    end else begin
      itime <= trenc_itime_i; 
    end 
  end 

  trenc_apb_reg inst_trenc_apb_reg (
	  .trenc_pclk_i                (trenc_pclk_i                           ),
	  .trenc_prstn_i               (trenc_prstn_i                          ),
	  .trenc_paddr_i               (trenc_paddr_i                          ),
	  .trenc_psel_i                (trenc_psel_i                           ),
	  .trenc_penable_i             (trenc_penable_i                        ),
	  .trenc_pwrite_i              (trenc_pwrite_i                         ), 
	  .trenc_pwdata_i              (trenc_pwdata_i                         ),
    .trenc_prdata_o              (trenc_prdata_o                         ),
	  .trenc_pready_o              (trenc_pready_o                         ),
	  .trenc_pslverr_o             (trenc_pslverr_o                        ),
	  .trenc_trctrl_enable_o       (trenc_trctrl_enable                    ),
	  .trenc_trctrl_start_o        (trenc_trctrl_start                     ),
	  .trenc_trctrl_tscon_o        (trenc_trctrl_tscon                     ),
	  .trenc_trctrl_compr_o        (trenc_trctrl_compr                     ),  //ioption[0]
	  .trenc_trctrl_tmode_o        (trenc_trctrl_tmode                     ),  //ioption[1]
	 // .trenc_trctrl_tfilter_o      (trenc_trctrl_tfilter                   ),  
	 // .trenc_tefilteraddr0l_o      (trenc_tefilteraddr0l                   ),
	 // .trenc_tefilteraddr0h_o      (trenc_tefilteraddr0h                   ),
	 // .trenc_tefilteraddr1l_o      (trenc_tefilteraddr1l                   ),
	 // .trenc_tefilteraddr1h_o      (trenc_tefilteraddr1h                   ),
    .trenc_teencoder_mode_o      (trenc_tecoder_mode                     ),
	  .trenc_tetime_o              (trenc_tetime                           )
	 // .trenc_tesync_o              (trenc_tesync                           ),
	 // .trenc_tesync_data_o         (trenc_tesync_data                      )
   );
/*
   trenc_clock_gating gclk_ctrl(
    .trenc_clk_i              (trenc_clk_i              ),
    .trenc_packet_fifo_empty_i(trenc_empty              ),
    .trenc_atb_empty_i        (trenc_atb_empty          ),
    .trenc_enable_i           (trenc_trctrl_enable      ),
    .trenc_clk_o              (gclk                     )
   );
*/
  trenc_algo inst_trenc_algo
  (
    .trenc_gclk_i         	     (gclk                                   ),  
    .trenc_rstn_i         	     (trenc_rstn_i                           ),  
    .inter_uop_i          	     (inter_uop_i                            ),  
    .trenc_mode_i         	     (trenc_trctrl_tmode                     ),   
    .trenc_expire_time_i  	     (trenc_tetime                           ),
    //.trenc_filter_i       	     (trenc_trctrl_tfilter                   ),
    //.trenc_filaddr0h_i    	     (trenc_tefilteraddr0h                   ),
    //.trenc_filaddr0l_i    	     (trenc_tefilteraddr0l                   ),
    //.trenc_filaddr1h_i    	     (trenc_tefilteraddr1h                   ),
    //.trenc_filaddr1l_i    	     (trenc_tefilteraddr1l                   ),
    .trenc_compress_i     	     (trenc_trctrl_compr                     ),
    .trenc_trctrl_enable_i	     (trenc_trctrl_enable                    ),  
    .trenc_trctrl_start_i 	     (trenc_trctrl_start                     ),
    //.trenc_trmode_i              (trenc_trctrl_tmode                     ),
    .trenc_pktlost_i      	     (trenc_pktlost                          ),
    .trenc_itime_i               (itime                                  ),
    .trenc_async_expt_vld_i      (trenc_async_expt_vld_i                 ),
    .trenc_int_vld_i             (trenc_int_vld_i                        ),
    .trenc_pkt_vld_o             (trenc_pkt_vld                          ),
    .trenc_pkt_o          	     (trenc_pkt                              ),
    .trenc_interrupt_o           (interrupt                              ),
    .trenc_stop_o                (trenc_stop                             ),
    .trenc_pkt_fmt_o             (pkt_fmt                                ),
    .trenc_sync_sfmt_o           (sync_sfmt                              )  
  );
  
  trenc_pktcomb inst_trenc_pktcomb                            
  (
    .trenc_gclk_i                (atclk_i                                ), 
    .trenc_rstn_i                (trenc_rstn_i                           ), 
    //.trenc_sync_i                (trenc_tesync                           ), 
    .trenc_comp_i                (trenc_trctrl_compr                     ),   
    .trenc_timectr_i             (trenc_trctrl_tscon                     ), 
    .trenc_core_id_i             (trenc_core_id_i                        ),
    //.trenc_syncdata_i            (trenc_tesync_data                      ),
    .trenc_pkt_i                 (trenc_pkt                              ), 
    .trenc_pkt_vld_i             (trenc_pkt_vld                          ),
    .itime_i                     (itime                                  ),
    .trenc_trctrl_enable_i       (trenc_trctrl_enable                    ),
    .trenc_trctrl_start_i        (trenc_trctrl_start                     ),   
    .trenc_trmode_i              (trenc_trctrl_tmode                     ), 
    .trenc_teinstmode_i          (trenc_tecoder_mode                     ),
    .trenc_interrupt_i           (interrupt                              ),
    .trenc_stop_i                (trenc_stop                             ),
    .trenc_pkt_lost_i            (trenc_pktlost                          ),
    .trenc_pkt_fmt_i             (pkt_fmt                                ),
    .trenc_sync_sfmt_i           (sync_sfmt                              ),
    .trenc_pkt_vld_o             (trenc_data_vld                         ),
    .trenc_data_o                (trenc_data                             ), 
    .trenc_data_len_o            (trenc_data_len                         )
  );
  
  always_comb begin
    if(|trenc_data_vld) begin
      for(int i = 0;i<INST_WIDTH;i++) begin
        trenc_fifo_data[i] = {trenc_data[i],trenc_data_len[i]}; 
      end 
    end else begin
      for(int i = 0;i<INST_WIDTH;i++) begin
        trenc_fifo_data[i] = {PUSH_WIDTH{1'b0}}; 
      end   
    end 
  end 
  
   trenc_sync_fifo inst_trenc_sync_fifo (
    .trenc_gclk_i                (atclk_i                                ),
    .trenc_rstn_i                (trenc_rstn_i                           ),
    .trenc_data_i                (trenc_fifo_data                        ),
    .trenc_valid_i               (trenc_data_vld                         ),
    .trenc_grant_o               (trenc_fifo_aval                        ),
    .trenc_data_o                (trenc_data_out                         ),
    .trenc_valid_o               (trenc_data_aval                        ),
    .trenc_grant_i               (trenc_buf_fetch                        ),
    .trenc_rd_ptr_o              (trenc_rd_ptr                           ),
    .trenc_wr_ptr_o              (trenc_wr_ptr                           ),
    .trenc_empty_o               (trenc_empty                            ),
    .trenc_full_o                (trenc_full                             )
    ,.trenc_pkt_lost_o           (trenc_pktlost                          )
 );  
  
  trenc_atb_data inst_trenc_atb_data
  (
    .trenc_gclk_i    	     (atclk_i            	                         ), 
    .trenc_rstn_i    	     (trenc_rstn_i                                 ), 
    .trenc_atbyte_o  	     (trenc_atbyte_o                               ), 
    .trenc_atdata_o  	     (trenc_atdata_o                               ), 
    .trenc_atid_o    	     (trenc_atid_o                                 ), 
    .trenc_atready_i 	     (trenc_atready_i                              ), 
    .trenc_atvalid_o 	     (trenc_atvalid_o                              ), 
    .trenc_afvalid_i 	     (trenc_afvalid_i                              ), 
    .trenc_afready_o 	     (trenc_afready_o                              ), 
    .trenc_bufdat_i  	     (trenc_data_out                               ),
    .trenc_bufreq_o        (trenc_buf_fetch                              ),
    .trenc_core_id_i       (trenc_core_id_i                              ),  
    .trenc_bufvld_i  	     (trenc_data_aval 	                           ), 
    .trenc_buffull_i 	     (trenc_full 	                                 ), 
    .trenc_bufempty_i	     (trenc_empty	                                 ),
    .trenc_wrptr_i   	     (trenc_wr_ptr 	                               ), 
    .trenc_rdptr_i   	     (trenc_rd_ptr 	                               ) 
  );
endmodule
