// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */

//import trenc_pkg::*;
module trenc_apb_reg
  import trenc_pkg::*;
(
   // APB intreface 
   input  logic                      trenc_pclk_i               ,
   input  logic                      trenc_prstn_i              ,
   input  logic[APBAWIDTH-1:0]       trenc_paddr_i              ,
   input  logic                      trenc_psel_i               ,
   input  logic                      trenc_penable_i            ,
   input  logic                      trenc_pwrite_i             ,
   input  logic[APBDWIDTH-1:0]       trenc_pwdata_i             ,
   output logic[APBDWIDTH-1:0]       trenc_prdata_o             ,
   output logic                      trenc_pready_o             ,
   output logic                      trenc_pslverr_o            ,
   // Trace encoder control signal 
   output logic                      trenc_trctrl_enable_o      ,  //trace enable
   output logic                      trenc_trctrl_start_o       ,  //trace start
   output logic                      trenc_trctrl_tscon_o       ,  //trace time
   output logic                      trenc_trctrl_compr_o       ,  //trace compress
   output logic                      trenc_trctrl_tmode_o       ,  //trace mode 
   //output logic[APBDWIDTH-1:0]       trenc_trctrl_tfilter_o     ,  //trace 
   //output logic[APBDWIDTH-1:0]       trenc_tefilteraddr0l_o     ,
   //output logic[APBDWIDTH-1:0]       trenc_tefilteraddr0h_o     ,
   //output logic[APBDWIDTH-1:0]       trenc_tefilteraddr1l_o     ,
   //output logic[APBDWIDTH-1:0]       trenc_tefilteraddr1h_o     ,
   output logic                      trenc_teencoder_mode_o     ,   //encoder mode
   output logic[TIME_WIDTH-1:0]      trenc_tetime_o                 //expire time  
   //output logic                      trenc_tesync_o             ,
   //output logic[SYNC_LEN-1:0]        trenc_tesync_data_o
);

  typedef enum logic [1:0] {IDLE, SETUP, ACCESSING} apb_state ;
  apb_state cs, ns;
  
  logic[APBAWIDTH-1:0] tr_addr_mask; 
  logic[APBAWIDTH-1:0] paddr_hi_bits;
  logic[APBAWIDTH-1:0] addr;
  logic dec_err;
  logic wr_enable, rd_enable;
  logic rw_ready;
  //logic [APBDWIDTH/8-1:0]    pstrb;

  
  logic[APBDWIDTH-1:0] reg_tecontrol        ;
  //logic[APBDWIDTH-1:0] reg_teimpl           ;
  logic[APBDWIDTH-1:0] reg_teinstfeatures   ;
  logic[APBDWIDTH-1:0] reg_tscontrol        ;
  //logic[APBDWIDTH-1:0] reg_tefltaddr0low    ;
  //logic[APBDWIDTH-1:0] reg_tefltaddr0high   ;
  //logic[APBDWIDTH-1:0] reg_tefltaddr1low    ;
  //logic[APBDWIDTH-1:0] reg_tefltaddr1high   ;
  //logic[APBDWIDTH-1:0] reg_teflter          ;
  logic[APBDWIDTH-1:0] reg_tetime           ;
  //logic[APBDWIDTH-1:0] reg_tesync           ;
  logic[APBDWIDTH-1:0] reg_tecom            ;
  //logic[APBDWIDTH-1:0] reg_teatbsink        ;
 
  //------------------------------ APB domain ---------------------------------------------------------
  always_ff @(posedge trenc_pclk_i or negedge trenc_prstn_i) begin
    if(!trenc_prstn_i) begin
      cs <= IDLE;
    end else begin
      cs <= ns;
    end
  end
  
  always_comb begin
    ns = IDLE;
    wr_enable = 0;
    rd_enable = 0;
    rw_ready  = 1;  
    case(cs)
      IDLE : begin
        if(trenc_psel_i && !trenc_penable_i) begin
          ns = SETUP;
          rw_ready = 0;
        end
      end
      SETUP : begin
        if(trenc_psel_i && trenc_penable_i) begin
          ns = ACCESSING;
          wr_enable = trenc_pwrite_i & ~dec_err;
          rd_enable = ~trenc_pwrite_i & ~dec_err;
        end
      end
      ACCESSING : begin
        if(trenc_psel_i && !trenc_penable_i) begin
          ns = SETUP;
          rw_ready = 0;
        end else begin
          ns = IDLE;
        end
      end
    endcase
  end
    
  assign tr_addr_mask  = {{APBAWIDTH-TR_AWIDTH{1'b1}},{TR_AWIDTH{1'b0}}};
  assign paddr_hi_bits = trenc_paddr_i & tr_addr_mask;
  assign dec_err       = (paddr_hi_bits != TR_BASE_ADDR) ? 1'b1 : 1'b0;
  
  assign trenc_pslverr_o = (ns == ACCESSING) ? dec_err : 0;
  assign trenc_pready_o = rw_ready;
  
  assign addr = {20'b0,trenc_paddr_i[TR_AWIDTH-1:0]};
   
  always_ff @(posedge trenc_pclk_i or negedge trenc_prstn_i) begin
    if(!trenc_prstn_i) begin
      reg_tecontrol       <=32'h00000000 ;
      //reg_teimpl          <=32'h00000000 ;
      reg_teinstfeatures  <=32'h00000000 ;
      reg_tscontrol       <=32'h00000000 ;
      //reg_tefltaddr0low   <=32'h00000000 ;
      //reg_tefltaddr0high  <=32'h00000000 ;
      //reg_tefltaddr1low   <=32'h00000000 ;
      //reg_tefltaddr1high  <=32'h00000000 ;
      //reg_teflter         <=32'h00000000 ;
      reg_tetime          <=32'h00000000 ;
      //reg_tesync          <=32'h00000000 ;
      reg_tecom           <=32'h00000000 ;
      //reg_teatbsink       <=32'b00000000 ;
    end else begin
      if(wr_enable) begin
        case(addr)
          REG_TECONTROL_ADDR:begin
            reg_tecontrol[P_TEACTIVE     ] <= trenc_pwdata_i[P_TEACTIVE     ];
            reg_tecontrol[P_TEENABLE     ] <= trenc_pwdata_i[P_TEENABLE     ];
            reg_tecontrol[P_TETRAC       ] <= trenc_pwdata_i[P_TETRAC       ];
            reg_tecontrol[P_TEINSTMODE+:3] <= trenc_pwdata_i[P_TEINSTMODE+:3];  
          end
          REG_TEINSTTEATURE_ADDR:begin
            reg_teinstfeatures[P_INSTNOADDRDIFF] <= trenc_pwdata_i[P_INSTNOADDRDIFF];
          end
          REG_TSCONTROL_ADDR:begin
            reg_tscontrol[P_TSACTIVE] <= trenc_pwdata_i[P_TSACTIVE];
          end 
          //REG_TEFLTADDR0LOW_ADDR:begin
          //  reg_tefltaddr0low[P_TRFLTADDR+:APBDWIDTH] <= trenc_pwdata_i[P_TRFLTADDR+:APBDWIDTH];
          //end
          //REG_TEFLTADDR1LOW_ADDR:begin
          //  reg_tefltaddr1low[P_TRFLTADDR+:APBDWIDTH] <= trenc_pwdata_i[P_TRFLTADDR+:APBDWIDTH];
          //end
          //REG_TEFLTADDR0HIGH_ADDR:begin
          //  reg_tefltaddr0high <= {25'b0,trenc_pwdata_i[P_TEFILTERH+:APBDWIDTH-25]};
          //end
          //REG_TEFLTADDR1HIGH_ADDR:begin
          //  reg_tefltaddr1high <= {25'b0,trenc_pwdata_i[P_TEFILTERH+:APBDWIDTH-25]};
          //end 
          //REG_TEFILTER_ADDR:begin
          //  reg_teflter[P_TEFILTERCON+:4] <= trenc_pwdata_i[P_TEFILTERCON+:4];
          //  reg_teflter[P_TEFILTERPRI+:2] <= trenc_pwdata_i[P_TEFILTERPRI+:2];
          //  reg_teflter[P_TEADDRABLE]     <= trenc_pwdata_i[P_TEADDRABLE];
          //  reg_teflter[P_TESEGADRABLE]   <= trenc_pwdata_i[P_TESEGADRABLE];
          //  reg_teflter[P_TECONTABLE]     <= trenc_pwdata_i[P_TECONTABLE];
          //  reg_teflter[P_TEPRIVABLE]     <= trenc_pwdata_i[P_TEPRIVABLE];
          //end 
          REG_TETIME_ADDR:begin
            reg_tetime[P_TETIME+:TIME_WIDTH]<= trenc_pwdata_i[P_TETIME+:TIME_WIDTH];
          end 
          //REG_TESYNC_ADDR:begin
          //  reg_tesync[P_TESYNCCONTR] <= trenc_pwdata_i[P_TESYNCCONTR];
          //  reg_tesync[P_TEDATA+:16]  <= trenc_pwdata_i[P_TEDATA+:16];
          //end 
          //REG_TECOM_ADDR:begin
          //  reg_tecom[P_TECOMPRESS]   <= trenc_pwdata_i[P_TECOMPRESS];	   
          //end 
        endcase
      end 
    end
  end
  
  always_comb begin
    trenc_prdata_o = 0; 
    if (rd_enable) begin 
      case(addr) 
        REG_TECONTROL_ADDR : begin
          trenc_prdata_o[P_TEACTIVE     ] = reg_tecontrol[P_TEACTIVE     ];//0
          trenc_prdata_o[P_TEENABLE     ] = reg_tecontrol[P_TEENABLE     ];//1
          trenc_prdata_o[P_TETRAC       ] = 1'b1;                          //2
          trenc_prdata_o[P_TEEMPTY      ] = 1'b1;                          //3
          trenc_prdata_o[P_TEINSTMODE+:3] = reg_tecontrol[P_TEINSTMODE+:3];//4-6
          trenc_prdata_o[15:7]            = 9'b0;                          //7-15
          trenc_prdata_o[P_TESYNCMODE+:2] = 2'b10;                         //16-17
          trenc_prdata_o[23:18]           = 6'b0;                          //18-23
          trenc_prdata_o[P_TEFORMAT+:3  ] = 3'b0 ;                         //24-26
          trenc_prdata_o[P_TESINK+:5    ] = 5'b00101;                      //27-31
        end
        REG_TEIMPL_ADDR : begin
          trenc_prdata_o[P_TEVISION+:4]  = 4'b0001;//0-3
          trenc_prdata_o[P_HASSPAMSINK]  = 1'b0;//4
          trenc_prdata_o[P_HASATBSIMK]   = 1'b1;//5
          trenc_prdata_o[P_HASPIBSINK]   = 1'b0;//6
          trenc_prdata_o[P_HASSBSINK]    = 1'b0;//7
          trenc_prdata_o[P_HASFUNNELSINK]= 1'b1;//8
          trenc_prdata_o[19:9]           = 11'b0;//9-19
          trenc_prdata_o[P_TESRCID+:4]   = 4'b1111;//20-23
          trenc_prdata_o[31:24]          = 8'b0;//24-31
        end  
        REG_TEINSTTEATURE_ADDR : begin
          trenc_prdata_o[P_INSTNOADDRDIFF]          = reg_teinstfeatures[P_INSTNOADDRDIFF];//0
          //trenc_prdata_o[P_INSTNOADDRDIFF]          = 1'b0;//0
          trenc_prdata_o[31:1]                      = 31'b0;//1-31        
        end
        REG_TSCONTROL_ADDR:begin
          trenc_prdata_o[P_TSACTIVE]                = reg_tscontrol[P_TSACTIVE];//0
          trenc_prdata_o[31:1]                      = 31'b0;//1-31
        end 
        //REG_TEFLTADDR0LOW_ADDR : begin
        //  trenc_prdata_o[P_TRFLTADDR+:APBDWIDTH]    = reg_tefltaddr0low[P_TRFLTADDR+:APBDWIDTH];  //0-31
        //end
        //REG_TEFLTADDR1LOW_ADDR : begin
        //  trenc_prdata_o[P_TRFLTADDR+:APBDWIDTH]    = reg_tefltaddr1low[P_TRFLTADDR+:APBDWIDTH];  //0-31
        //end                                                                                       
        //REG_TEFLTADDR0HIGH_ADDR : begin                                                               
        //  trenc_prdata_o[P_TEFILTERH+:APBDWIDTH-25] = reg_tefltaddr0high[P_TEFILTERH+:APBDWIDTH-25];//0-6
        //  trenc_prdata_o[31:7]                      = 25'b0;//7-31
        //end
        //REG_TEFLTADDR1HIGH_ADDR : begin
        //  trenc_prdata_o[P_TEFILTERH+:APBDWIDTH-25] = reg_tefltaddr1high[P_TEFILTERH+:APBDWIDTH-25];//0-6
        //  trenc_prdata_o[31:7]                      = 25'b0;//7-31
        //end
        //REG_TEFILTER_ADDR : begin
        //  trenc_prdata_o[P_TEFILTERCON+:4] = reg_teflter[P_TEFILTERCON+:4];//0-3
        //  trenc_prdata_o[P_TEFILTERPRI+:2] = reg_teflter[P_TEFILTERPRI+:2];//4-5
        //  trenc_prdata_o[P_TEADDRABLE]     = reg_teflter[P_TEADDRABLE];    //6
        //  trenc_prdata_o[P_TESEGADRABLE]   = reg_teflter[P_TESEGADRABLE];  //7
        //  trenc_prdata_o[P_TECONTABLE]     = reg_teflter[P_TECONTABLE];    //8
        //  trenc_prdata_o[P_TEPRIVABLE]     = reg_teflter[P_TEPRIVABLE];    //9
        //  trenc_prdata_o[31:10]            = 22'b0;                        //10-31
        //end
        REG_TETIME_ADDR : begin
          trenc_prdata_o[P_TETIME+:TIME_WIDTH] = reg_tetime[P_TETIME+:TIME_WIDTH];//0-31
        end
        //REG_TESYNC_ADDR:begin
        //  trenc_prdata_o[P_TESYNCCONTR] = reg_tesync[P_TESYNCCONTR] ;//0
        //  trenc_prdata_o[P_TEFLAG] = 1'b1;		//1
        //  trenc_prdata_o[17:2]     =16'b0;
        //  trenc_prdata_o[31:18]    =14'b0;
        // end 
        //REG_TECOM_ADDR:begin
        //  trenc_prdata_o[P_TECOMPRESS] = reg_tecom[P_TECOMPRESS];
        //  trenc_prdata_o[31:1]         = 31'b0;
        //end
        default:begin
          trenc_prdata_o = 32'b0;  
        end 
      endcase
    end
  end
  
  assign trenc_trctrl_enable_o    = reg_tecontrol[P_TEENABLE] ;
  assign trenc_trctrl_start_o     = reg_tecontrol[P_TEACTIVE] ;
  assign trenc_trctrl_tscon_o     = reg_tscontrol[P_TSACTIVE] ;
  assign trenc_trctrl_compr_o     = 1'b0;
  assign trenc_trctrl_tmode_o     = 1'b1;
  //assign trenc_trctrl_tmode_o     = reg_teinstfeatures[P_INSTNOADDRDIFF];
  //assign trenc_trctrl_tfilter_o   = reg_teflter[P_TEFILTERCON+:10];
  //assign trenc_tefilteraddr0l_o   = reg_tefltaddr0low;
  //assign trenc_tefilteraddr0h_o   = reg_tefltaddr0high;
  //assign trenc_tefilteraddr1l_o   = reg_tefltaddr1low;
  //assign trenc_tefilteraddr1h_o   = reg_tefltaddr1high;
  assign trenc_teencoder_mode_o   = reg_tecontrol[P_TEINSTMODE];
  assign trenc_tetime_o           = reg_tetime[P_TETIME+:TIME_WIDTH];
  //assign trenc_tesync_o           = reg_tesync[P_TESYNCCONTR];
  //assign trenc_tesync_data_o      = reg_tesync[P_TEDATA+:16];
endmodule
