// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */

package trenc_pkg;

  localparam TR_ATBID_CORE0               = 7'h0F;
  localparam TR_ATBID_CORE1               = 7'h1F;
  localparam TR_ATBID_CORE2               = 7'h2F;
  localparam TR_ATBID_CORE3               = 7'h3F; 
  localparam APBDWIDTH                    = 32; //APB data    width 
  localparam APBAWIDTH                    = 32; //APB address width
  localparam TR_AWIDTH                     = 12;
  localparam TR_BASE_ADDR                 = 32'h00000000;
  localparam REG_TECONTROL_ADDR           = 12'h000;
  localparam REG_TEIMPL_ADDR              = 12'h004;
  localparam REG_TEINSTTEATURE_ADDR       = 12'h008;
  localparam REG_TSCONTROL_ADDR           = 12'h040;
  localparam REG_TEFLTADDR0LOW_ADDR       = 12'h3F8;
  localparam REG_TEFLTADDR1LOW_ADDR       = 12'h414;
  localparam REG_TEFLTADDR0HIGH_ADDR      = 12'h3FC;
  localparam REG_TEFLTADDR1HIGH_ADDR      = 12'h418;
  localparam REG_TEFILTER_ADDR            = 12'h410;
  localparam REG_TETIME_ADDR              = 12'h41C;
  localparam REG_TESYNC_ADDR              = 12'h420;
  localparam REG_TECOM_ADDR               = 12'h424;
  
  localparam P_TEACTIVE                   = 0 ;
  localparam P_TEENABLE                   = 1 ;
  localparam P_TETRAC                     = 2 ;
  localparam P_TEEMPTY                    = 3 ;
  localparam P_TEINSTMODE                 = 4 ;
  localparam P_TEINSTSTALL                = 12;
  localparam P_TEINSTENABLE               = 13;
  localparam P_TESTOPONWRAP               = 14;
  localparam P_TEINHIBITSRC               = 15;
  localparam P_TESYNCMODE                 = 16;
  localparam P_TEFORMAT                   = 24;
  localparam P_TESINK                     = 27;
  
  localparam P_TEVISION                   = 0 ;
  localparam P_HASSPAMSINK                = 4 ;
  localparam P_HASATBSIMK                 = 5 ;
  localparam P_HASPIBSINK                 = 6 ;
  localparam P_HASSBSINK                  = 7 ;
  localparam P_HASFUNNELSINK              = 8 ;
  localparam P_TESRCID                    = 20;
  
  localparam P_INSTNOADDRDIFF             = 0 ;
  
  localparam P_TSACTIVE                   = 0;
  localparam P_TEFILTER                   = 0;
  
  localparam P_TEFILTERL                  = 0;
  localparam P_TEFILTERH                  = 0;
  
  localparam P_TETIME                     = 0;
  
  localparam P_TESYNCCONTR                = 0;
  localparam P_TEFLAG                     = 1;
  localparam P_TEDATA                     = 2;
   
  localparam P_TEFILTERCON                = 0;
  localparam P_TEFILTERPRI                = 4;
  localparam P_TEADDRABLE                 = 6;
  localparam P_TESEGADRABLE               = 7;
  localparam P_TECONTABLE                 = 8;  
  localparam P_TEPRIVABLE                 = 9;
  localparam P_TRFLTADDR                  = 0;
  
  localparam P_TECOMPRESS                 = 0;
  
  localparam P_TEATBSINK                  = 1;
  
  localparam SYNC_LEN                     = 'd16 ;
  localparam ATBWIDTH                     = 'd64 ;
  localparam ARCH                         = 'd0  ;
  localparam CONTEXT_WIDTH                = 'd20  ;
  
  localparam ECAUSE_WIDTH                 = 'd6  ;
  localparam IADDRESS_WIDTH               = 'd39 ;
  localparam PRIVILEGE_WIDTH              = 'd2  ;
  localparam TIME_WIDTH                   = 'd16 ; 
  localparam SUBFORMAT_LEN                = 'd2  ;
  
  localparam HEADER_LEN                   = 5;
  localparam FORMAT_LEN                   = 2;
  localparam SYNC_SFORMAT_LEN             = 3;
  localparam THADDR_LEN                   = 2;
  localparam OPT_SFORMAT_LEN              = 2;
  localparam FILTER_LEN                   = 4;
  localparam QUAL_STATUS_LEN              = 2;
  
  localparam IADDR_LEN                    = IADDRESS_WIDTH ;
  localparam PRIV_LEN                     = PRIVILEGE_WIDTH ;
  localparam TIME_LEN                     = TIME_WIDTH ;
  localparam CONT_LEN                     = CONTEXT_WIDTH ;
  localparam ENCODER_MODE_LEN             = 1 ;
  localparam OPTION_LEN                   = 2 ;
  localparam ECAUSE_LEN                   = ECAUSE_WIDTH ;
  localparam TVAL_LEN                     = IADDR_LEN+1;
  localparam CONTEX_LEN                   = CONTEXT_WIDTH;
  localparam BRANCH_LEN                   = 5 ;
  localparam BRMAP_LEN                    = 31;
  localparam INST_WIDTH                   = 4 ;
  localparam HDR_LEN                      = 8 ; 
  localparam COUNT_WIDTH                  = 16;
  localparam DEPTH                        = 8;  
  localparam FULL_MODE                    = 1;
  localparam DIFF_MODE                    = 0;

  localparam PAYLOAD_LEN                  = 136;
  localparam PKTDATA_LEN                  = PAYLOAD_LEN + TIME_LEN + HDR_LEN;
  localparam PKTDATA_WIDTH                = 8;
  localparam PUSH_WIDTH                   = PKTDATA_LEN + PKTDATA_WIDTH;
  localparam POP_WIDTH                    = PKTDATA_LEN + PKTDATA_WIDTH;
   //pkt_len
  localparam SF_START_WIDTH               = 8'd82;  //format0 subdormat0
  localparam SF_TRAP_NINT_WIDTH           = 8'd90;  //format0 subdormat1
  localparam SF_TRAP_INT_WIDTH            = 8'd130; //format0 subdormat1
  localparam SF_CONTEXT_WIDTH             = 8'd26;  

  localparam HEADER_TIME_WIDRH            = 8'd24;
  localparam HEADER_NTIME_WIDRH           = 8'd8;
  localparam SF_ADDR_WIDTH                = 8'd43;
  localparam SF_BRA_ADDR_WIDTH            = 8'd79;
  localparam SF_BRA_NADDR_WIDTH           = 8'd38;
  
  typedef enum logic[FORMAT_LEN-1:0] {
     FORMAT3        = 2'h3,
     FORMAT2        = 2'h2,
     FORMAT1        = 2'h1,
     FORMAT0        = 2'h0
  } pkt_format_t;
  
  typedef enum logic[SYNC_SFORMAT_LEN-1:0] {
     SF_START     = 3'h0,  //format 3 subformat 0
     SF_TRAP      = 3'h1,  //format 3 subformat 1
     SF_CONTEXT   = 3'h2,  //format 3 subformat 2
     SF_SUPPORT   = 3'h3,  //format 3 subformat 3
     SF_ADDR      = 3'h4,
     SF_BRA_ADDR  = 3'h5,  //format 1 address 
     SF_BRA_NADDR = 3'h6   //format 1 no address
  } pkt_sync_sformat_t;
  
  typedef enum logic {
     SF_THADDR0      = 1'h0,
     SF_THADDR1      = 1'h1
  } pkt_thaddr_sformat_t;
  
  typedef enum logic[FILTER_LEN-1:0] {
     ADDRABLE     = 'b0001,
     SEGDABLE     = 'b0010,
     CONTABLE     = 'b0100,
     PRIVABLE     = 'b1000
  }filter_mode;
  
  typedef enum logic[QUAL_STATUS_LEN-1:0] {
     NO_CHANGE    = 2'b00,
     ENDED_REP    = 2'b01,
     TRACE_LOST   = 2'b10,
     ENDED_NTR    = 2'b11
  } qual_status_t;
  
  
  // microop_t total is 118bit
  // etrace
  typedef struct packed{
    logic [38:0] iaddr    ;  
    logic [3:0]  itype    ;  
    logic [1:0]  priv     ;  
    logic [39:0] tval     ;  
    logic [5:0]  cause    ;  
    logic [2:0]  iretire  ;  
    logic        ilastsize;   
    logic        ivalid   ;   
    logic [19:0] cont     ;  
    logic [1:0]  inst_num ;
  }microop_t;

  // n_microop_t total is 87bit
  // ntrace
  //typedef struct packed{
  //  logic        vld;
  //  logic [2:0]  itype;
  //  logic [38:0] iaddr;
  //  logic [38:0] next_pc;
  //  logic [2:0]  iretire;
  //  logic [1:0]  ilastsize;
  //}n_microop_t;


/*  
  typedef struct packed{
    logic [38:0] iaddr    ;  
    logic [3:0]  itype    ;  
    logic [1:0]  priv     ;  
    logic [39:0] tval     ;  
    logic [5:0]  cause    ;  
    logic [2:0]  iretire  ;  
    logic        ilastsize;   
    logic        ivalid   ;   
    logic [19:0] cont     ;  
  }mic_uop;
*/

endpackage


   
