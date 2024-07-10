// SPDX-License-Identifier: MPL-2.0
/*
 *
 * Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
 *
 */
module trenc_sync_fifo
  import trenc_pkg::*;
(
  input  logic                    trenc_gclk_i              ,
  input  logic                    trenc_rstn_i              ,
  // push 
  input  logic[PUSH_WIDTH-1:0]    trenc_data_i  [INST_WIDTH],    
  input  logic[INST_WIDTH-1:0]    trenc_valid_i             ,  
  output logic                    trenc_grant_o             ,   
  // pop
  output logic[POP_WIDTH-1:0]     trenc_data_o              ,   
  output logic                    trenc_valid_o             ,    
  input  logic                    trenc_grant_i             ,  
  // statue
  output logic[$clog2(DEPTH)-1:0] trenc_rd_ptr_o            ,
  output logic[$clog2(DEPTH)-1:0] trenc_wr_ptr_o            ,
  output logic                    trenc_empty_o             ,
  output logic                    trenc_full_o              ,
  output logic                    trenc_pkt_lost_o 
);

  integer i;
  enum logic[1:0] {EMPTY, FULL, NORMAL} cs, ns;
  
  logic [$clog2(DEPTH)-1:0] wr_ptr_q, rd_ptr_q;
  logic [$clog2(DEPTH)-1:0] wr_ptr_d, rd_ptr_d;
  logic [PUSH_WIDTH-1:0] fifo_reg[DEPTH-1:0];
  logic trenc_valid;
  logic [2:0] trenc_valid_data;
  logic [2:0] fifo_full,fifo_full_q;
  logic fifo_full_vld;
  logic pkt_lost;
  logic fifo_flush,fifo_flush_q;
  logic [INST_WIDTH-1:0]    trenc_valid_full;
  logic [PUSH_WIDTH-1:0]    trenc_data_q  [INST_WIDTH];
  logic [INST_WIDTH-1:0]    trenc_valid_q             ;
  logic [2:0] trenc_valid_data_number;


  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if (!trenc_rstn_i) begin
      trenc_valid_q <= 4'b0;
    end 
    else if(pkt_lost) begin
      trenc_valid_q <= 4'b0;
    end
    else if(trenc_grant_i && fifo_flush) begin
      trenc_valid_q <= 4'b0;    
    end 
    else begin
       trenc_valid_q <= trenc_valid_i;
    end 
  end

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      for(int i = 0;i<INST_WIDTH;i=i+1) trenc_data_q[i] <= 'b0;
    end 
    else begin
      for(int i = 0;i<INST_WIDTH;i=i+1) trenc_data_q[i] <= trenc_data_i[i];
    end 
  end 
  
  assign trenc_valid_data_number = trenc_valid_q[0] + trenc_valid_q[1] + trenc_valid_q[2] + trenc_valid_q[3];
/*
  always_comb begin
    fifo_full =3'b0;
    if(trenc_valid_data_number == 'd1) begin
      if((wr_ptr_q + 1 ) % DEPTH  == rd_ptr_q) fifo_full = 3'd1;
      else fifo_full = 3'd0;
    end
    else if(trenc_valid_data_number == 'd2) begin
      if((wr_ptr_q + 1 ) % DEPTH  == rd_ptr_q)  fifo_full = 3'd1;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q )   fifo_full = 3'd2 ;
      else fifo_full = 3'b0; 
    end
    else if(trenc_valid_data_number == 'd3) begin
      if((wr_ptr_q + 1 ) % DEPTH  == rd_ptr_q) fifo_full = 3'd1;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q) fifo_full = 3'd2;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q )  fifo_full =3'd3;
      else fifo_full  = 3'd0;
    end 
    else if(trenc_valid_data_number == 'd4) begin
      if((wr_ptr_q + 1 ) % DEPTH  == rd_ptr_q) fifo_full = 3'd1;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q) fifo_full = 3'd2;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q && (wr_ptr_q + 2) % DEPTH == rd_ptr_q )  fifo_full = 3'd3;
      else if((wr_ptr_q + 1 ) % DEPTH  != rd_ptr_q && (wr_ptr_q + 2) % DEPTH != rd_ptr_q && (wr_ptr_q + 3) % DEPTH != rd_ptr_q && (wr_ptr_q + 4) % DEPTH == rd_ptr_q )  fifo_full=3'd4;
      else  fifo_full= 3'd0;
    end 
  end 

*/

  always_comb begin
    fifo_full =3'b0;
    if(trenc_valid_data_number == 'd1) begin
      if( (wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1- DEPTH) == rd_ptr_q )                                                                                 fifo_full = 3'd1;
      else                                                                                                                                                           fifo_full = 3'd0;
    end
    else if(trenc_valid_data_number == 'd2) begin
      if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) == rd_ptr_q )                                                                                   fifo_full = 3'd1 ;
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q  + 2- DEPTH) == rd_ptr_q)   fifo_full = 3'd2 ;
      else                                                                                                                                                           fifo_full = 3'b0; 
    end
    else if(trenc_valid_data_number == 'd3) begin
      if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1- DEPTH) == rd_ptr_q )                                                                                  fifo_full = 3'd1;
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q  && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q + 2- DEPTH) == rd_ptr_q)   fifo_full = 3'd2;
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q  && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q + 2- DEPTH) != rd_ptr_q && (wr_ptr_q + 3 < DEPTH ? wr_ptr_q + 3 : wr_ptr_q + 3- DEPTH) == rd_ptr_q)                                                                                                                  fifo_full = 3'd3;
      else                                                                                                                                                           fifo_full = 3'd0;
    end 
    else if(trenc_valid_data_number == 'd4) begin
      if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1- DEPTH) == rd_ptr_q )                                                                                  fifo_full = 3'd1;
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q  && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q + 2- DEPTH) == rd_ptr_q)   fifo_full = 3'd2;
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q  && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q + 1- DEPTH) != rd_ptr_q && (wr_ptr_q + 3 < DEPTH ? wr_ptr_q + 3 : wr_ptr_q + 3- DEPTH) == rd_ptr_q)                                                                                                                  fifo_full = 3'd3; 
      else if((wr_ptr_q + 1 < DEPTH ? wr_ptr_q + 1 : wr_ptr_q + 1- DEPTH) != rd_ptr_q  && (wr_ptr_q + 2 < DEPTH ? wr_ptr_q + 2 : wr_ptr_q + 2- DEPTH) != rd_ptr_q && (wr_ptr_q + 3 < DEPTH ? wr_ptr_q + 3 : wr_ptr_q + 3- DEPTH) != rd_ptr_q  && (wr_ptr_q + 4 < DEPTH ? wr_ptr_q + 4 : wr_ptr_q + 4- DEPTH) == rd_ptr_q )                                     fifo_full = 3'd4;
      else                                                                                                                                                           fifo_full = 3'd0;
    end 
  end 

/*
  always_comb begin
    trenc_valid_full = trenc_valid_q;
    if(|fifo_full) begin
      if(fifo_full == 3'd4 ) begin
        trenc_valid_full[2:0] = trenc_valid_q[2:0];
        trenc_valid_full[3]   = 1'b0;
      end 
      else if(fifo_full == 3'd3) begin
        trenc_valid_full[1:0] = trenc_valid_q[1:0];
        trenc_valid_full[3:2] = 2'b0;
      end 
      else if(fifo_full == 3'd2 ) begin
        trenc_valid_full[0]   = trenc_valid_q[0];
        trenc_valid_full[3:1] = 3'b0;
      end
      else if(fifo_full == 3'd1 ) begin
        trenc_valid_full[3:0] = 4'b0;
      end 
      else begin
        trenc_valid_full[3:0] = 4'b0;
      end 
    end 
  end 
*/

  always_comb begin
    trenc_valid_full = trenc_valid_q;
    if(|fifo_full) begin
      if(fifo_full == 3'd4 ) begin
        trenc_valid_full[3:0] = trenc_valid_q[3:0];
      end 
      else if(fifo_full == 3'd3) begin
        trenc_valid_full[2:0] = trenc_valid_q[2:0];
        trenc_valid_full[3]   = 1'b0;
      end 
      else if(fifo_full == 3'd2 ) begin
        trenc_valid_full[1:0] = trenc_valid_q[1:0];
        trenc_valid_full[3:2] = 2'b0;
      end
      else if(fifo_full == 3'd1 ) begin
        trenc_valid_full[0]   = trenc_valid_q[0];
        trenc_valid_full[3:1] = 3'b0;
      end 
      else begin
        trenc_valid_full[3:0] = 4'b0;
      end 
    end 
  end 
  assign fifo_full_vld    = |fifo_full; 
  
  assign trenc_valid = |trenc_valid_full && ~fifo_flush;

  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      fifo_full_q <= 3'b0;
    end else begin
      fifo_full_q <= fifo_full;
    end 
  end 

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      fifo_flush_q <= 1'b0;
    end 
    else begin
      fifo_flush_q <= fifo_flush;
    end 
  end

  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      fifo_flush  <= 1'b0;  
    end 
    //else if (trenc_grant_i && ~fifo_full_vld) begin
    else if (trenc_grant_i) begin
      fifo_flush  <= 1'b0;  
    end 
    else if (fifo_full_vld) begin
      fifo_flush  <= 1'b1;
    end 
  end
  
  assign pkt_lost = ~fifo_flush  & fifo_flush_q;

  assign trenc_valid_data = trenc_valid_full[0] + trenc_valid_full[1] + trenc_valid_full[2] + trenc_valid_full[3];


  always_ff @(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if(!trenc_rstn_i) begin
      wr_ptr_q <= 0;
      rd_ptr_q <= 0; 
      cs       <= EMPTY;
    end
    else if(fifo_flush && trenc_grant_i ) begin
      wr_ptr_q <= 0;
      rd_ptr_q <= 0; 
      cs       <= EMPTY;
    end
    else begin
      wr_ptr_q <= wr_ptr_d;
      rd_ptr_q <= rd_ptr_d;
      cs       <= ns;
    end
  end
  
  always_comb begin
    wr_ptr_d = wr_ptr_q;
    rd_ptr_d = rd_ptr_q;
    ns       = cs;
    trenc_grant_o  = 1'b1;
    trenc_valid_o  = 1'b0;
    case(cs)
      EMPTY : begin
        trenc_grant_o  = 1'b1;
        trenc_valid_o  = 1'b0;
        if(trenc_valid) begin
          ns       = NORMAL;
          if(wr_ptr_q + trenc_valid_data <DEPTH) wr_ptr_d = wr_ptr_q + trenc_valid_data;
          else wr_ptr_d = (wr_ptr_q + trenc_valid_data) - DEPTH; 
        end else begin
          ns = EMPTY;      
        end 
      end
      NORMAL : begin
        trenc_grant_o  = 1'b1;
        trenc_valid_o  = 1'b1;
        if(trenc_valid && !trenc_grant_i) begin            //wr_en !rd_en
          //wr_ptr_d = (wr_ptr_q + trenc_valid_data) % DEPTH;
          wr_ptr_d = (wr_ptr_q + trenc_valid_data) < DEPTH ? (wr_ptr_q + trenc_valid_data) : (wr_ptr_q + trenc_valid_data - DEPTH);
          case(trenc_valid_data)
            //3'd1:ns = (((wr_ptr_q + 1 ) % DEPTH) == rd_ptr_q) ? FULL:NORMAL;
            //3'd2:ns = (((wr_ptr_q + 1 ) % DEPTH) == rd_ptr_q  || ((wr_ptr_q + 2) % DEPTH) == rd_ptr_q) ? FULL:NORMAL;
            //3'd3:ns = (((wr_ptr_q + 1 ) % DEPTH) == rd_ptr_q  || ((wr_ptr_q + 2) % DEPTH) == rd_ptr_q || ((wr_ptr_q + 2) % DEPTH) == rd_ptr_q ) ? FULL:NORMAL;
            //3'd4:ns = (((wr_ptr_q + 1 ) % DEPTH) == rd_ptr_q  || ((wr_ptr_q + 2) % DEPTH) == rd_ptr_q || ((wr_ptr_q + 3) % DEPTH) == rd_ptr_q || ((wr_ptr_q + 4) % DEPTH) == rd_ptr_q) ? FULL:NORMAL;
            3'd1:ns = (((wr_ptr_q + 1 )  < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1 - DEPTH  ) == rd_ptr_q) ? FULL:NORMAL;
            3'd2:ns = (((wr_ptr_q + 1 )  < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 2 )  < DEPTH ? wr_ptr_q + 2 :  wr_ptr_q + 2 - DEPTH  ) == rd_ptr_q) ? FULL:NORMAL;
           
            3'd3:ns = (((wr_ptr_q + 1 )  < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 2 )  < DEPTH ? wr_ptr_q + 2 :  wr_ptr_q + 2 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 3 )  < DEPTH ? wr_ptr_q + 3 :  wr_ptr_q + 3 - DEPTH  ) == rd_ptr_q) ? FULL:NORMAL;

            3'd4:ns = (((wr_ptr_q + 1 )  < DEPTH ? wr_ptr_q + 1 :  wr_ptr_q + 1 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 2 )  < DEPTH ? wr_ptr_q + 2 :  wr_ptr_q + 2 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 3 )  < DEPTH ? wr_ptr_q + 3 :  wr_ptr_q + 3 - DEPTH  ) == rd_ptr_q) ||(((wr_ptr_q + 4 )  < DEPTH ? wr_ptr_q + 3 :  wr_ptr_q + 4 - DEPTH  ) == rd_ptr_q) ? FULL:NORMAL;
            
            default:ns = ((wr_ptr_q  < DEPTH ? wr_ptr_q : wr_ptr_q - DEPTH) == rd_ptr_q ) ? FULL:NORMAL;  
          endcase  
        end else if(!trenc_valid && trenc_grant_i) begin   //!wr_en  rd_en 
          //rd_ptr_d = (rd_ptr_q + 1) % DEPTH;
          //ns = (((rd_ptr_q + 1) % DEPTH) == wr_ptr_q) ? EMPTY:NORMAL;	
          rd_ptr_d =  rd_ptr_q + 1 < DEPTH ? (rd_ptr_q + 1) : (rd_ptr_q + 1 - DEPTH);
          ns = (rd_ptr_d == wr_ptr_q) ? EMPTY:NORMAL;
        end else if(trenc_valid && trenc_grant_i) begin    //wr_en rd_en 
          //rd_ptr_d = (rd_ptr_q + 1'b1)% DEPTH;
          //wr_ptr_d = (wr_ptr_q + trenc_valid_data) % DEPTH;
          rd_ptr_d =  rd_ptr_q + 1'b1 < DEPTH ? (rd_ptr_q + 1) : (rd_ptr_q + 1 - DEPTH);
          wr_ptr_d =  wr_ptr_q + trenc_valid_data < DEPTH ? (wr_ptr_q + trenc_valid_data) : (wr_ptr_q + trenc_valid_data - DEPTH);
         case(trenc_valid_data)
            3'd1:ns = (( rd_ptr_q + 1'b1) == ((wr_ptr_q + 1) % DEPTH)) ? EMPTY:NORMAL;
            3'd2:ns = (((rd_ptr_q + 1'b1) == ((wr_ptr_q + 1) % DEPTH)) || ((rd_ptr_q + 1'b1) == ((wr_ptr_q + 2) % DEPTH))) ? EMPTY:NORMAL;
            3'd3:ns = (((rd_ptr_q + 1'b1) == ((wr_ptr_q + 1) % DEPTH)) || ((rd_ptr_q + 1'b1) == ((wr_ptr_q + 2) % DEPTH)) || ((rd_ptr_q + 1'b1) == ((wr_ptr_q + 3) % DEPTH)) ) ? EMPTY:NORMAL;
            3'd4:ns = (rd_ptr_q + 1'b1 == (wr_ptr_q + 1) % DEPTH || rd_ptr_q + 1'b1 == (wr_ptr_q + 2) % DEPTH || rd_ptr_q + 1'b1 == (wr_ptr_q + 3) % DEPTH || rd_ptr_q + 1'b1 == (wr_ptr_q + 4)% DEPTH ) ? EMPTY:NORMAL; 
            default:ns = ((rd_ptr_q + 1'b1) == (wr_ptr_q % DEPTH)) ? EMPTY:NORMAL;  
          endcase 
        end else begin //!wr_en !rd_en
          ns = NORMAL;
        end 
      end
      FULL : begin
        trenc_grant_o  = 1'b0;
        trenc_valid_o  = 1'b1;
        if(trenc_grant_i) begin
          ns       = NORMAL;
          if(rd_ptr_q + 1 < DEPTH) rd_ptr_d = rd_ptr_q + 1;
          else rd_ptr_d =  (rd_ptr_q + 1) - DEPTH; 
        end else begin
          ns = FULL;
        end 
      end
    endcase
  end


  always_ff@(posedge trenc_gclk_i or negedge trenc_rstn_i) begin
    if (!trenc_rstn_i) begin
      for(i=0; i<DEPTH; i++) fifo_reg[i] <= {PUSH_WIDTH{1'b0}};
    end
    else if(trenc_grant_i && fifo_flush) begin
      for(i=0; i<DEPTH; i++) fifo_reg[i] <= {PUSH_WIDTH{1'b0}};
    end
    else begin
      if(trenc_grant_o && trenc_valid) begin
        case(trenc_valid_full)
          4'b0001:begin
            fifo_reg[wr_ptr_q]                                           <= trenc_data_q[0];
          end
          4'b0011:begin
            fifo_reg[wr_ptr_q]                                           <= trenc_data_q[0];
            fifo_reg[wr_ptr_q+1 < DEPTH ? wr_ptr_q+1:wr_ptr_q+1-DEPTH]   <= trenc_data_q[1];
          end 
          4'b0111:begin
            fifo_reg[wr_ptr_q]                                           <= trenc_data_q[0];
            fifo_reg[wr_ptr_q+1 < DEPTH ? wr_ptr_q+1:wr_ptr_q+1-DEPTH]   <= trenc_data_q[1];
            fifo_reg[wr_ptr_q+2 < DEPTH ? wr_ptr_q+2:wr_ptr_q+2-DEPTH]   <= trenc_data_q[2];
          end
          4'b1111:begin
            fifo_reg[wr_ptr_q]                                           <= trenc_data_q[0];
            fifo_reg[wr_ptr_q+1 < DEPTH ? wr_ptr_q+1:wr_ptr_q+1-DEPTH]   <= trenc_data_q[1];
            fifo_reg[wr_ptr_q+2 < DEPTH ? wr_ptr_q+2:wr_ptr_q+2-DEPTH]   <= trenc_data_q[2]; 
            fifo_reg[wr_ptr_q+3 < DEPTH ? wr_ptr_q+3:wr_ptr_q+3-DEPTH]   <= trenc_data_q[3]; 
          end
          default:begin
            fifo_reg[wr_ptr_q]     <= {PUSH_WIDTH{1'b0}}; 
          end
        endcase 
      end 
    end 
  end 


  assign trenc_empty_o    = (cs == EMPTY) ? 'b1:'b0;
  assign trenc_full_o     = (cs == FULL)? 'b1:'b0;
  assign trenc_rd_ptr_o   = rd_ptr_q;
  assign trenc_wr_ptr_o   = wr_ptr_q;
  assign trenc_data_o     = fifo_reg[rd_ptr_q];
  assign trenc_pkt_lost_o = pkt_lost;
endmodule
