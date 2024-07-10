// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
module trenc_filter
  import trenc_pkg::*;
(
  input  microop_t                                 inter_uop                 ,
  input  logic                                   trenc_start_i             ,
  //input  logic                                   trenc_clk_i               ,
  //input  logic                                   trenc_rst_i               ,
  //input  logic [APBDWIDTH-1:0]                   trenc_filter_i            ,
  //input  logic [APBDWIDTH-1:0]                   trenc_filaddr0h_i         ,
  //input  logic [APBDWIDTH-1:0]                   trenc_filaddr0l_i         ,
  //input  logic [APBDWIDTH-1:0]                   trenc_filaddr1h_i         ,
  //input  logic [APBDWIDTH-1:0]                   trenc_filaddr1l_i         ,
  output logic                                   trenc_qualified_o         ,
  output logic                                   trenc_qualified_first_o           
);
/*
  logic        range_match    ;
  logic        segment_match  ;
  logic        context_match  ;
  logic        priv_match     ;
  logic [31:0] range_mask0    ;
  logic [31:0] range_mask1    ;
  logic        segment_range_match;
  logic        trenc_qualified;
  */
  logic        trenc_qualified_first;

 /* 
  microop_t interface_uop_slot_filter ;
  logic [3:0]  trenc_filter_mode         ;
  localparam    ADDRABLE     = 'b0001;
  localparam    SEGDABLE     = 'b0010;
  localparam    CONTABLE     = 'b0100;
  localparam    PRIVABLE     = 'b1000;

  assign interface_uop_slot_filter = inter_uop;
  
  assign range_match   = (interface_uop_slot_filter.iaddr > {trenc_filaddr0l_i[31:25],trenc_filaddr0h_i[31:0]})
          && (interface_uop_slot_filter.iaddr < {trenc_filaddr1l_i[31:25],trenc_filaddr1h_i[31:0]}) ? 1'b1:1'b0;
  assign context_match = (interface_uop_slot_filter.cont == trenc_filter_i[3:0]) ? 1'b1:1'b0;
  assign priv_match    = (interface_uop_slot_filter.priv == trenc_filter_i[5:4]) ? 1'b1:1'b0;
  assign segment_match = segment_range_match?1'b1:1'b0;

  always_comb begin
    range_mask0 = 32'b1;
    if     (!trenc_filaddr1l_i[ 0]) range_mask0 = 32'b11111111111111111111111111111110;
    else if(!trenc_filaddr1l_i[ 1]) range_mask0 = 32'b11111111111111111111111111111100;
    else if(!trenc_filaddr1l_i[ 2]) range_mask0 = 32'b11111111111111111111111111111000;
    else if(!trenc_filaddr1l_i[ 3]) range_mask0 = 32'b11111111111111111111111111110000;
    else if(!trenc_filaddr1l_i[ 4]) range_mask0 = 32'b11111111111111111111111111100000;
    else if(!trenc_filaddr1l_i[ 5]) range_mask0 = 32'b11111111111111111111111111000000;
    else if(!trenc_filaddr1l_i[ 6]) range_mask0 = 32'b11111111111111111111111110000000;
    else if(!trenc_filaddr1l_i[ 7]) range_mask0 = 32'b11111111111111111111111100000000;
    else if(!trenc_filaddr1l_i[ 8]) range_mask0 = 32'b11111111111111111111111000000000;
    else if(!trenc_filaddr1l_i[ 9]) range_mask0 = 32'b11111111111111111111110000000000;
    else if(!trenc_filaddr1l_i[10]) range_mask0 = 32'b11111111111111111111100000000000;
    else if(!trenc_filaddr1l_i[11]) range_mask0 = 32'b11111111111111111111000000000000;
    else if(!trenc_filaddr1l_i[12]) range_mask0 = 32'b11111111111111111110000000000000;
    else if(!trenc_filaddr1l_i[13]) range_mask0 = 32'b11111111111111111100000000000000;
    else if(!trenc_filaddr1l_i[14]) range_mask0 = 32'b11111111111111111000000000000000;
    else if(!trenc_filaddr1l_i[15]) range_mask0 = 32'b11111111111111110000000000000000;
    else if(!trenc_filaddr1l_i[16]) range_mask0 = 32'b11111111111111100000000000000000;
    else if(!trenc_filaddr1l_i[17]) range_mask0 = 32'b11111111111111000000000000000000;
    else if(!trenc_filaddr1l_i[18]) range_mask0 = 32'b11111111111110000000000000000000;
    else if(!trenc_filaddr1l_i[19]) range_mask0 = 32'b11111111111100000000000000000000;
    else if(!trenc_filaddr1l_i[20]) range_mask0 = 32'b11111111111000000000000000000000;
    else if(!trenc_filaddr1l_i[21]) range_mask0 = 32'b11111111110000000000000000000000;
    else if(!trenc_filaddr1l_i[22]) range_mask0 = 32'b11111111100000000000000000000000;
    else if(!trenc_filaddr1l_i[23]) range_mask0 = 32'b11111111000000000000000000000000;
    else if(!trenc_filaddr1l_i[24]) range_mask0 = 32'b11111110000000000000000000000000;
    else if(!trenc_filaddr1l_i[25]) range_mask0 = 32'b11111100000000000000000000000000;
    else if(!trenc_filaddr1l_i[26]) range_mask0 = 32'b11111000000000000000000000000000;
    else if(!trenc_filaddr1l_i[27]) range_mask0 = 32'b11110000000000000000000000000000;
    else if(!trenc_filaddr1l_i[28]) range_mask0 = 32'b11100000000000000000000000000000;
    else if(!trenc_filaddr1l_i[29]) range_mask0 = 32'b11000000000000000000000000000000;
    else if(!trenc_filaddr1l_i[30]) range_mask0 = 32'b10000000000000000000000000000000;
    else if(!trenc_filaddr1l_i[31]) range_mask0 = 32'b00000000000000000000000000000000;
  end 

  always_comb begin
    range_mask1 = 32'b1;
    if     (!trenc_filaddr1h_i[0]) range_mask1 = 32'b11111111111111111111111111111110;
    else if(!trenc_filaddr1h_i[1]) range_mask1 = 32'b11111111111111111111111111111100;
    else if(!trenc_filaddr1h_i[2]) range_mask1 = 32'b11111111111111111111111111111000;
    else if(!trenc_filaddr1h_i[3]) range_mask1 = 32'b11111111111111111111111111110000;
    else if(!trenc_filaddr1h_i[4]) range_mask1 = 32'b11111111111111111111111111100000;
    else if(!trenc_filaddr1h_i[5]) range_mask1 = 32'b11111111111111111111111111000000;
    else if(!trenc_filaddr1h_i[6]) range_mask1 = 32'b11111111111111111111111110000000;
    else if(!trenc_filaddr1h_i[7]) range_mask1 = 32'b11111111111111111111111100000000;
  end

  always_comb begin
    if (((interface_uop_slot_filter.iaddr[31:0] & range_mask0) == (trenc_filaddr1l_i & range_mask0)) 
    && (({25'b0,interface_uop_slot_filter.iaddr[38:32]} & range_mask1) == (trenc_filaddr1h_i & range_mask1))) begin
      segment_range_match = 'b1;
    end else begin
      segment_range_match = 'b0;
    end
  end 
  */

  /*
  always_comb begin
    case(trenc_filter_i[9:6]) 
      4'b0000:begin
    		trenc_qualified = 1'b1;			
    	end 
    	4'b0001:begin  
    		if(range_match) trenc_qualified = 1'b1;
    		else            trenc_qualified = 1'b0;
    	end
    	4'b0010:begin
    		if(segment_match) trenc_qualified = 1'b1;
    		else              trenc_qualified = 1'b0;
    	end
    	4'b0011:begin
    		if( context_match && segment_match ) trenc_qualified = 1'b1;
    		else                                 trenc_qualified = 1'b0;
    	end
    	4'b0100:begin
    		if(context_match) trenc_qualified = 1'b1;
    		else              trenc_qualified = 1'b0;
    	end 
    	4'b0101:begin  
    		if(range_match && context_match) trenc_qualified = 1'b1;
    		else                             trenc_qualified = 1'b0;
    	end 
    	4'b0111:begin 
    		if(range_match && segment_match && context_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1000:begin
    		if(priv_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1001:begin
    		if(priv_match && context_match) 	trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1010:begin
    		if(priv_match && segment_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1100:begin
    		if(priv_match && context_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1110:begin
    		if(priv_match && context_match && segment_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end 
    	4'b1111:begin
    		if(range_match && context_match && segment_match && priv_match) trenc_qualified = 1'b1;
    		else    trenc_qualified = 1'b0;
    	end
    	default trenc_qualified = 1'b0;	
    endcase  
  end 
*/
  
  //assign trenc_qualified_o       = trenc_qualified;
  //assign trenc_qualified_first = ((range_match || context_match || context_match || segment_match)  && trenc_start_i)? 'b1:'b0;
  assign trenc_qualified_first   = (1'b1  && trenc_start_i)? 'b1:'b0; 
  assign trenc_qualified_o       = 1'b1;
  assign trenc_qualified_first_o = trenc_qualified_first;
  
endmodule 
