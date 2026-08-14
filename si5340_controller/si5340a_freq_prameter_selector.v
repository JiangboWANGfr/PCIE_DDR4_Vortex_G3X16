module si5340a_freq_prameter_selector (

input         [3:0]          iPLL_OUT_FREQ_SEL,

//output   reg  [23:0]         RX_REG,
output   reg                 OUTX_OE,
output   reg  [43:0]         NX_NUM,
output   reg  [31:0]         NX_DEN       

);


//`define XCVR_REF_644M53125     4'h0  
//`define XCVR_REF_322M265625    4'h1  
//`define XCVR_REF_250M          4'h2  
//`define XCVR_REF_125M          4'h3  
//`define XCVR_REF_100M          4'h4  
//
//`define MEM_REF_300M     4'h0+5  // for DDR4 2400
//`define MEM_REF_275M     4'h1+5  // for QDRII+ 550MHz
//`define MEM_REF_266M667  4'h2+5  // for DDR4 2133 and QDRIV 1066Mhz
//`define MEM_REF_233M333  4'h3+5  // for DDR4 1866
//`define MEM_REF_166M667  4'h4+5  // for DDR4 2666


always @(*)
  begin
     case(iPLL_OUT_FREQ_SEL[3:0])
	  
      4'h0 :   //644.53125 MHz
        begin
          OUTX_OE <= 1'b1 ;
          NX_NUM  <= 44'd23622320128;
        end
      4'h1 :   //322.265625 MHz
        begin
          OUTX_OE <= 1'b1 ;
          NX_NUM  <= 44'd47244640256;
        end
      4'h2 :   //250.0 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd60901294080;

        end
      4'h3 :   //125.0 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd121802588160;
        end                     
      4'h4 :   //100.0 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd152253235200;
        end               
			 		
		//---MEM DDR---   
      4'h5 :   //300.0 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd50751078400;
        end               
      4'h6 :   //275.0 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd55364812800;
        end               
      4'h7 :   //266.667 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd57094963200;
        end               
		  
      4'h8 :   //233.333 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd65251386514;
        end               
		
      4'h9 :   //166.667 MHz
        begin
          OUTX_OE <= 1'b1;
          NX_NUM  <= 44'd91351941120;
        end               
		  		  
       //4'ha :   //power down
          //begin
         // OUTX_OE = 1'b0;
         // NX_NUM = 44'd0;
        //end                 
      default :   //100Mhz
        begin
          OUTX_OE = 1'b1;
          NX_NUM = 44'd152253235200;
        end                         
      endcase
  end
  

endmodule
