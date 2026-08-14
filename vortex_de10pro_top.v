// ============================================================================
// Copyright (c) 2018 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development
//   Kits made by Terasic.  Other use of this code, including the selling
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use
//   or functionality of this code.
//
// ============================================================================
//
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Wed Jan 31 14:15:58 2018
// ============================================================================

`define ENABLE_DDR4A
`define ENABLE_DDR4B
`define ENABLE_DDR4C
`define ENABLE_DDR4D
`define ENABLE_PCIE
`define ENABLE_PCIE_16
//`define ENABLE_QSFP28A
//`define ENABLE_QSFP28B
//`define ENABLE_QSFP28C
//`define ENABLE_QSFP28D

module vortex_de10pro_top(

      ///////// CLOCK /////////
      input              CLK_100_B3I,
      input              CLK_50_B2C,
      input              CLK_50_B2L,
      input              CLK_50_B3C,
      input              CLK_50_B3I,
      input              CLK_50_B3L,

      ///////// Buttons /////////
      input              CPU_RESET_n,
      input    [ 1: 0]   BUTTON,

      ///////// Swtiches /////////
      input    [ 1: 0]   SW,

      ///////// LED /////////
      output   [ 3: 0]   LED, //LED is Low-Active

      ///////// FLASH /////////
      output             FLASH_CLK,
      output   [27: 1]   FLASH_A,
      inout    [15: 0]   FLASH_D,
      output             FLASH_CE_n,
      output             FLASH_WE_n,
      output             FLASH_OE_n,
      output             FLASH_ADV_n,
      output             FLASH_RESET_n,
      input              FLASH_RDY_BSY_n,

`ifdef ENABLE_DDR4A
      ///////// DDR4A /////////
      input              DDR4A_REFCLK_p,
      output   [16: 0]   DDR4A_A,
      output   [ 1: 0]   DDR4A_BA,
      output   [ 1: 0]   DDR4A_BG,
      output             DDR4A_CK,
      output             DDR4A_CK_n,
      output             DDR4A_CKE,
      inout    [ 7: 0]   DDR4A_DQS,
      inout    [ 7: 0]   DDR4A_DQS_n,
      inout    [63: 0]   DDR4A_DQ,
      inout    [ 7: 0]   DDR4A_DBI_n,
      output             DDR4A_CS_n,
      output             DDR4A_RESET_n,
      output             DDR4A_ODT,
      output             DDR4A_PAR,
      input              DDR4A_ALERT_n,
      output             DDR4A_ACT_n,
      input              DDR4A_EVENT_n,
      inout              DDR4A_SCL,
      inout              DDR4A_SDA,
      input              DDR4A_RZQ,
`endif /*ENABLE_DDR4A*/

`ifdef ENABLE_DDR4B
      ///////// DDR4B /////////
      input              DDR4B_REFCLK_p,
      output   [16: 0]   DDR4B_A,
      output   [ 1: 0]   DDR4B_BA,
      output   [ 1: 0]   DDR4B_BG,
      output             DDR4B_CK,
      output             DDR4B_CK_n,
      output             DDR4B_CKE,
      inout    [ 7: 0]   DDR4B_DQS,
      inout    [ 7: 0]   DDR4B_DQS_n,
      inout    [63: 0]   DDR4B_DQ,
      inout    [ 7: 0]   DDR4B_DBI_n,
      output             DDR4B_CS_n,
      output             DDR4B_RESET_n,
      output             DDR4B_ODT,
      output             DDR4B_PAR,
      input              DDR4B_ALERT_n,
      output             DDR4B_ACT_n,
      input              DDR4B_EVENT_n,
      inout              DDR4B_SCL,
      inout              DDR4B_SDA,
      input              DDR4B_RZQ,
`endif /*ENABLE_DDR4B*/

`ifdef ENABLE_DDR4C
      ///////// DDR4C /////////
      input              DDR4C_REFCLK_p,
      output   [16: 0]   DDR4C_A,
      output   [ 1: 0]   DDR4C_BA,
      output   [ 1: 0]   DDR4C_BG,
      output             DDR4C_CK,
      output             DDR4C_CK_n,
      output             DDR4C_CKE,
      inout    [ 7: 0]   DDR4C_DQS,
      inout    [ 7: 0]   DDR4C_DQS_n,
      inout    [63: 0]   DDR4C_DQ,
      inout    [ 7: 0]   DDR4C_DBI_n,
      output             DDR4C_CS_n,
      output             DDR4C_RESET_n,
      output             DDR4C_ODT,
      output             DDR4C_PAR,
      input              DDR4C_ALERT_n,
      output             DDR4C_ACT_n,
      input              DDR4C_EVENT_n,
      inout              DDR4C_SCL,
      inout              DDR4C_SDA,
      input              DDR4C_RZQ,
`endif /*ENABLE_DDR4C*/

`ifdef ENABLE_DDR4D
      ///////// DDR4D /////////
      input              DDR4D_REFCLK_p,
      output   [16: 0]   DDR4D_A,
      output   [ 1: 0]   DDR4D_BA,
      output   [ 1: 0]   DDR4D_BG,
      output             DDR4D_CK,
      output             DDR4D_CK_n,
      output             DDR4D_CKE,
      inout    [ 7: 0]   DDR4D_DQS,
      inout    [ 7: 0]   DDR4D_DQS_n,
      inout    [63: 0]   DDR4D_DQ,
      inout    [ 7: 0]   DDR4D_DBI_n,
      output             DDR4D_CS_n,
      output             DDR4D_RESET_n,
      output             DDR4D_ODT,
      output             DDR4D_PAR,
      input              DDR4D_ALERT_n,
      output             DDR4D_ACT_n,
      input              DDR4D_EVENT_n,
      inout              DDR4D_SCL,
      inout              DDR4D_SDA,
      input              DDR4D_RZQ,
`endif /*ENABLE_DDR4D*/

      ///////// SI5340A0 /////////
      inout              SI5340A0_I2C_SCL,
      inout              SI5340A0_I2C_SDA,
      input              SI5340A0_INTR,
      output             SI5340A0_OE_n,
      output             SI5340A0_RST_n,

      ///////// SI5340A1 /////////
      inout              SI5340A1_I2C_SCL,
      inout              SI5340A1_I2C_SDA,
      input              SI5340A1_INTR,
      output             SI5340A1_OE_n,
      output             SI5340A1_RST_n,

      ///////// I2Cs /////////
      inout              FAN_I2C_SCL,
      inout              FAN_I2C_SDA,
      input              FAN_ALERT_n,
      inout              POWER_MONITOR_I2C_SCL,
      inout              POWER_MONITOR_I2C_SDA,
      input              POWER_MONITOR_ALERT_n,
      inout              TEMP_I2C_SCL,
      inout              TEMP_I2C_SDA,

      ///////// GPIO /////////
      inout    [ 1: 0]   GPIO_CLK,
      inout    [ 3: 0]   GPIO_P,

`ifdef ENABLE_PCIE
      ///////// PCIE /////////
      inout              PCIE_SMBCLK,
      inout              PCIE_SMBDAT,
      input              PCIE_REFCLK_p,
`ifndef ENABLE_PCIE_16
      output   [ 7: 0]   PCIE_TX_p,
      input    [ 7: 0]   PCIE_RX_p,
`else
      output   [15: 0]   PCIE_TX_p,
      input    [15: 0]   PCIE_RX_p,
`endif /*ENABLE_PCIE_16*/
      input              PCIE_PERST_n,
      output             PCIE_WAKE_n,
`endif /*ENABLE_PCIE*/

`ifdef ENABLE_QSFP28A
      ///////// QSFP28A /////////
      input              QSFP28A_REFCLK_p,
      output   [ 3: 0]   QSFP28A_TX_p,
      input    [ 3: 0]   QSFP28A_RX_p,
      input              QSFP28A_INTERRUPT_n,
      output             QSFP28A_LP_MODE,
      input              QSFP28A_MOD_PRS_n,
      output             QSFP28A_MOD_SEL_n,
      output             QSFP28A_RST_n,
      inout              QSFP28A_SCL,
      inout              QSFP28A_SDA,
`endif /*ENABLE_QSFP28A*/

`ifdef ENABLE_QSFP28B
      ///////// QSFP28B /////////
      input              QSFP28B_REFCLK_p,
      output   [ 3: 0]   QSFP28B_TX_p,
      input    [ 3: 0]   QSFP28B_RX_p,
      input              QSFP28B_INTERRUPT_n,
      output             QSFP28B_LP_MODE,
      input              QSFP28B_MOD_PRS_n,
      output             QSFP28B_MOD_SEL_n,
      output             QSFP28B_RST_n,
      inout              QSFP28B_SCL,
      inout              QSFP28B_SDA,
`endif /*ENABLE_QSFP28B*/

`ifdef ENABLE_QSFP28C
      ///////// QSFP28C /////////
      input              QSFP28C_REFCLK_p,
      output   [ 3: 0]   QSFP28C_TX_p,
      input    [ 3: 0]   QSFP28C_RX_p,
      input              QSFP28C_INTERRUPT_n,
      output             QSFP28C_LP_MODE,
      input              QSFP28C_MOD_PRS_n,
      output             QSFP28C_MOD_SEL_n,
      output             QSFP28C_RST_n,
      inout              QSFP28C_SCL,
      inout              QSFP28C_SDA,
`endif /*ENABLE_QSFP28C*/

`ifdef ENABLE_QSFP28D
      ///////// QSFP28D /////////
      input              QSFP28D_REFCLK_p,
      output   [ 3: 0]   QSFP28D_TX_p,
      input    [ 3: 0]   QSFP28D_RX_p,
      input              QSFP28D_INTERRUPT_n,
      output             QSFP28D_LP_MODE,
      input              QSFP28D_MOD_PRS_n,
      output             QSFP28D_MOD_SEL_n,
      output             QSFP28D_RST_n,
      inout              QSFP28D_SCL,
      inout              QSFP28D_SDA,
`endif /*ENABLE_QSFP28D*/

       ///////// EXP /////////
      input              EXP_EN,

      ///////// UFL /////////
      inout              UFL_CLKIN_p,
      inout              UFL_CLKIN_n

);

wire [1:0]   pio_button;

wire ddr4a_local_reset_done;
wire ddr4a_local_cal_success;
wire ddr4a_local_cal_fail;
wire ddr4b_local_reset_done;
wire ddr4b_local_cal_success;
wire ddr4b_local_cal_fail;
wire ddr4c_local_reset_done;
wire ddr4c_local_cal_success;
wire ddr4c_local_cal_fail;
wire ddr4d_local_reset_done;
wire ddr4d_local_cal_success;
wire ddr4d_local_cal_fail;
wire si5340a0_config_done;
wire si5340a0_i2c_id_read_error;
wire si5340a1_config_done;
wire si5340a1_i2c_id_read_error;

localparam [3:0] XCVR_REF_644M53125 = 4'h0;
localparam [3:0] XCVR_REF_250M      = 4'h2;
localparam [3:0] MEM_REF_166M667    = 4'h4;

wire [31:0] hip_ctrl_test_in;

assign hip_ctrl_test_in = 32'h000000A8;
assign PCIE_WAKE_n = 1'b1;

// LEDs are low-active. SW selects DDR4 status for channels A..D on LED0..3.
wire [3:0] ddr4_led_status;
assign ddr4_led_status =
    (SW == 2'b00) ? {ddr4d_local_cal_success, ddr4c_local_cal_success,
                     ddr4b_local_cal_success, ddr4a_local_cal_success} :
    (SW == 2'b01) ? {ddr4d_local_cal_fail, ddr4c_local_cal_fail,
                     ddr4b_local_cal_fail, ddr4a_local_cal_fail} :
    (SW == 2'b10) ? {ddr4d_local_reset_done, ddr4c_local_reset_done,
                     ddr4b_local_reset_done, ddr4a_local_reset_done} :
                      {si5340a1_config_done, si5340a1_config_done,
                       si5340a0_config_done, si5340a0_config_done};
assign LED = ~ddr4_led_status;
assign pio_button = ~BUTTON; // button low-active

//////////////////////
// PCIE RESET
wire             any_rstn;
reg              any_rstn_r /* synthesis ALTERA_ATTRIBUTE = "SUPPRESS_DA_RULE_INTERNAL=R102"  */;
reg              any_rstn_rr /* synthesis ALTERA_ATTRIBUTE = "SUPPRESS_DA_RULE_INTERNAL=R102"  */;
reg              si5340_rstn_r /* synthesis ALTERA_ATTRIBUTE = "SUPPRESS_DA_RULE_INTERNAL=R102"  */;
reg              si5340_rstn_rr /* synthesis ALTERA_ATTRIBUTE = "SUPPRESS_DA_RULE_INTERNAL=R102"  */;

assign any_rstn = PCIE_PERST_n & CPU_RESET_n;

//reset Synchronizer
always @(posedge CLK_50_B2C or negedge any_rstn) begin
    if (any_rstn == 0) begin
        any_rstn_r <= 0;
        any_rstn_rr <= 0;
    end else begin
        any_rstn_r <= 1;
        any_rstn_rr <= any_rstn_r;
    end
end

always @(posedge CLK_50_B2C or negedge CPU_RESET_n) begin
    if (CPU_RESET_n == 0) begin
        si5340_rstn_r <= 0;
        si5340_rstn_rr <= 0;
    end else begin
        si5340_rstn_r <= 1;
        si5340_rstn_rr <= si5340_rstn_r;
    end
end


pcie_ddr4_system u_pcie_ddr4_system (
		.refclk_clk                              (PCIE_REFCLK_p),                              //   input,   width = 1,        refclk.clk
		.pcie_rstn_npor                          (any_rstn_rr),                          //   input,   width = 1,     pcie_rstn.npor
		.pcie_rstn_pin_perst                     (PCIE_PERST_n),                     //   input,   width = 1,              .pin_perst
		.hip_ctrl_test_in                        (hip_ctrl_test_in),                        //   input,  width = 67,              .test_in

		.xcvr_rx_in0                             (PCIE_RX_p[0]),                             //   input,   width = 1,          xcvr.rx_in0
		.xcvr_rx_in1                             (PCIE_RX_p[1]),                             //   input,   width = 1,              .rx_in1
		.xcvr_rx_in2                             (PCIE_RX_p[2]),                             //   input,   width = 1,              .rx_in2
		.xcvr_rx_in3                             (PCIE_RX_p[3]),                             //   input,   width = 1,              .rx_in3
		.xcvr_rx_in4                             (PCIE_RX_p[4]),                             //   input,   width = 1,              .rx_in4
		.xcvr_rx_in5                             (PCIE_RX_p[5]),                             //   input,   width = 1,              .rx_in5
		.xcvr_rx_in6                             (PCIE_RX_p[6]),                             //   input,   width = 1,              .rx_in6
		.xcvr_rx_in7                             (PCIE_RX_p[7]),                             //   input,   width = 1,              .rx_in7
		.xcvr_rx_in8                             (PCIE_RX_p[8]),                             //   input,   width = 1,              .rx_in8
		.xcvr_rx_in9                             (PCIE_RX_p[9]),                             //   input,   width = 1,              .rx_in9
		.xcvr_rx_in10                            (PCIE_RX_p[10]),                            //   input,   width = 1,              .rx_in10
		.xcvr_rx_in11                            (PCIE_RX_p[11]),                            //   input,   width = 1,              .rx_in11
		.xcvr_rx_in12                            (PCIE_RX_p[12]),                            //   input,   width = 1,              .rx_in12
		.xcvr_rx_in13                            (PCIE_RX_p[13]),                            //   input,   width = 1,              .rx_in13
		.xcvr_rx_in14                            (PCIE_RX_p[14]),                            //   input,   width = 1,              .rx_in14
		.xcvr_rx_in15                            (PCIE_RX_p[15]),                            //   input,   width = 1,              .rx_in15
		.xcvr_tx_out0                            (PCIE_TX_p[0]),                            //  output,   width = 1,              .tx_out0
		.xcvr_tx_out1                            (PCIE_TX_p[1]),                            //  output,   width = 1,              .tx_out1
		.xcvr_tx_out2                            (PCIE_TX_p[2]),                            //  output,   width = 1,              .tx_out2
		.xcvr_tx_out3                            (PCIE_TX_p[3]),                            //  output,   width = 1,              .tx_out3
		.xcvr_tx_out4                            (PCIE_TX_p[4]),                            //  output,   width = 1,              .tx_out4
		.xcvr_tx_out5                            (PCIE_TX_p[5]),                            //  output,   width = 1,              .tx_out5
		.xcvr_tx_out6                            (PCIE_TX_p[6]),                            //  output,   width = 1,              .tx_out6
		.xcvr_tx_out7                            (PCIE_TX_p[7]),                            //  output,   width = 1,              .tx_out7
		.xcvr_tx_out8                            (PCIE_TX_p[8]),                            //  output,   width = 1,              .tx_out8
		.xcvr_tx_out9                            (PCIE_TX_p[9]),                            //  output,   width = 1,              .tx_out9
		.xcvr_tx_out10                           (PCIE_TX_p[10]),                           //  output,   width = 1,              .tx_out10
		.xcvr_tx_out11                           (PCIE_TX_p[11]),                           //  output,   width = 1,              .tx_out11
		.xcvr_tx_out12                           (PCIE_TX_p[12]),                           //  output,   width = 1,              .tx_out12
		.xcvr_tx_out13                           (PCIE_TX_p[13]),                           //  output,   width = 1,              .tx_out13
		.xcvr_tx_out14                           (PCIE_TX_p[14]),                           //  output,   width = 1,              .tx_out14
		.xcvr_tx_out15                           (PCIE_TX_p[15]),                           //  output,   width = 1,              .tx_out15

		.emif_s10_ddr4a_local_reset_req_local_reset_req       (1'b0),                      //   input,   width = 1
		.emif_s10_ddr4a_local_reset_status_local_reset_done   (ddr4a_local_reset_done),    //  output,   width = 1
		.emif_s10_ddr4a_pll_ref_clk_clk                       (DDR4A_REFCLK_p),             //   input,   width = 1
		.emif_s10_ddr4a_oct_oct_rzqin                         (DDR4A_RZQ),                  //   input,   width = 1
		.emif_s10_ddr4a_mem_mem_ck                            (DDR4A_CK),                   //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_ck_n                          (DDR4A_CK_n),                 //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_a                             (DDR4A_A),                    //  output,  width = 17
		.emif_s10_ddr4a_mem_mem_act_n                         (DDR4A_ACT_n),                //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_ba                            (DDR4A_BA),                   //  output,   width = 2
		.emif_s10_ddr4a_mem_mem_bg                            (DDR4A_BG),                   //  output,   width = 2
		.emif_s10_ddr4a_mem_mem_cke                           (DDR4A_CKE),                  //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_cs_n                          (DDR4A_CS_n),                 //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_odt                           (DDR4A_ODT),                  //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_reset_n                       (DDR4A_RESET_n),              //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_par                           (DDR4A_PAR),                  //  output,   width = 1
		.emif_s10_ddr4a_mem_mem_alert_n                       (DDR4A_ALERT_n),              //   input,   width = 1
		.emif_s10_ddr4a_mem_mem_dqs                           (DDR4A_DQS),                  //   inout,   width = 8
		.emif_s10_ddr4a_mem_mem_dqs_n                         (DDR4A_DQS_n),                //   inout,   width = 8
		.emif_s10_ddr4a_mem_mem_dq                            (DDR4A_DQ),                   //   inout,  width = 64
		.emif_s10_ddr4a_mem_mem_dbi_n                         (DDR4A_DBI_n),                //   inout,   width = 8
		.emif_s10_ddr4a_status_local_cal_success              (ddr4a_local_cal_success),    //  output,   width = 1
		.emif_s10_ddr4a_status_local_cal_fail                 (ddr4a_local_cal_fail),       //  output,   width = 1

		.emif_s10_ddr4b_local_reset_req_local_reset_req       (1'b0),
		.emif_s10_ddr4b_local_reset_status_local_reset_done   (ddr4b_local_reset_done),
		.emif_s10_ddr4b_pll_ref_clk_clk                       (DDR4B_REFCLK_p),
		.emif_s10_ddr4b_oct_oct_rzqin                         (DDR4B_RZQ),
		.emif_s10_ddr4b_mem_mem_ck                            (DDR4B_CK),
		.emif_s10_ddr4b_mem_mem_ck_n                          (DDR4B_CK_n),
		.emif_s10_ddr4b_mem_mem_a                             (DDR4B_A),
		.emif_s10_ddr4b_mem_mem_act_n                         (DDR4B_ACT_n),
		.emif_s10_ddr4b_mem_mem_ba                            (DDR4B_BA),
		.emif_s10_ddr4b_mem_mem_bg                            (DDR4B_BG),
		.emif_s10_ddr4b_mem_mem_cke                           (DDR4B_CKE),
		.emif_s10_ddr4b_mem_mem_cs_n                          (DDR4B_CS_n),
		.emif_s10_ddr4b_mem_mem_odt                           (DDR4B_ODT),
		.emif_s10_ddr4b_mem_mem_reset_n                       (DDR4B_RESET_n),
		.emif_s10_ddr4b_mem_mem_par                           (DDR4B_PAR),
		.emif_s10_ddr4b_mem_mem_alert_n                       (DDR4B_ALERT_n),
		.emif_s10_ddr4b_mem_mem_dqs                           (DDR4B_DQS),
		.emif_s10_ddr4b_mem_mem_dqs_n                         (DDR4B_DQS_n),
		.emif_s10_ddr4b_mem_mem_dq                            (DDR4B_DQ),
		.emif_s10_ddr4b_mem_mem_dbi_n                         (DDR4B_DBI_n),
		.emif_s10_ddr4b_status_local_cal_success              (ddr4b_local_cal_success),
		.emif_s10_ddr4b_status_local_cal_fail                 (ddr4b_local_cal_fail),

		.emif_s10_ddr4c_local_reset_req_local_reset_req       (1'b0),
		.emif_s10_ddr4c_local_reset_status_local_reset_done   (ddr4c_local_reset_done),
		.emif_s10_ddr4c_pll_ref_clk_clk                       (DDR4C_REFCLK_p),
		.emif_s10_ddr4c_oct_oct_rzqin                         (DDR4C_RZQ),
		.emif_s10_ddr4c_mem_mem_ck                            (DDR4C_CK),
		.emif_s10_ddr4c_mem_mem_ck_n                          (DDR4C_CK_n),
		.emif_s10_ddr4c_mem_mem_a                             (DDR4C_A),
		.emif_s10_ddr4c_mem_mem_act_n                         (DDR4C_ACT_n),
		.emif_s10_ddr4c_mem_mem_ba                            (DDR4C_BA),
		.emif_s10_ddr4c_mem_mem_bg                            (DDR4C_BG),
		.emif_s10_ddr4c_mem_mem_cke                           (DDR4C_CKE),
		.emif_s10_ddr4c_mem_mem_cs_n                          (DDR4C_CS_n),
		.emif_s10_ddr4c_mem_mem_odt                           (DDR4C_ODT),
		.emif_s10_ddr4c_mem_mem_reset_n                       (DDR4C_RESET_n),
		.emif_s10_ddr4c_mem_mem_par                           (DDR4C_PAR),
		.emif_s10_ddr4c_mem_mem_alert_n                       (DDR4C_ALERT_n),
		.emif_s10_ddr4c_mem_mem_dqs                           (DDR4C_DQS),
		.emif_s10_ddr4c_mem_mem_dqs_n                         (DDR4C_DQS_n),
		.emif_s10_ddr4c_mem_mem_dq                            (DDR4C_DQ),
		.emif_s10_ddr4c_mem_mem_dbi_n                         (DDR4C_DBI_n),
		.emif_s10_ddr4c_status_local_cal_success              (ddr4c_local_cal_success),
		.emif_s10_ddr4c_status_local_cal_fail                 (ddr4c_local_cal_fail),

		.emif_s10_ddr4d_local_reset_req_local_reset_req       (1'b0),
		.emif_s10_ddr4d_local_reset_status_local_reset_done   (ddr4d_local_reset_done),
		.emif_s10_ddr4d_pll_ref_clk_clk                       (DDR4D_REFCLK_p),
		.emif_s10_ddr4d_oct_oct_rzqin                         (DDR4D_RZQ),
		.emif_s10_ddr4d_mem_mem_ck                            (DDR4D_CK),
		.emif_s10_ddr4d_mem_mem_ck_n                          (DDR4D_CK_n),
		.emif_s10_ddr4d_mem_mem_a                             (DDR4D_A),
		.emif_s10_ddr4d_mem_mem_act_n                         (DDR4D_ACT_n),
		.emif_s10_ddr4d_mem_mem_ba                            (DDR4D_BA),
		.emif_s10_ddr4d_mem_mem_bg                            (DDR4D_BG),
		.emif_s10_ddr4d_mem_mem_cke                           (DDR4D_CKE),
		.emif_s10_ddr4d_mem_mem_cs_n                          (DDR4D_CS_n),
		.emif_s10_ddr4d_mem_mem_odt                           (DDR4D_ODT),
		.emif_s10_ddr4d_mem_mem_reset_n                       (DDR4D_RESET_n),
		.emif_s10_ddr4d_mem_mem_par                           (DDR4D_PAR),
		.emif_s10_ddr4d_mem_mem_alert_n                       (DDR4D_ALERT_n),
		.emif_s10_ddr4d_mem_mem_dqs                           (DDR4D_DQS),
		.emif_s10_ddr4d_mem_mem_dqs_n                         (DDR4D_DQS_n),
		.emif_s10_ddr4d_mem_mem_dq                            (DDR4D_DQ),
		.emif_s10_ddr4d_mem_mem_dbi_n                         (DDR4D_DBI_n),
		.emif_s10_ddr4d_status_local_cal_success              (ddr4d_local_cal_success),
		.emif_s10_ddr4d_status_local_cal_fail                 (ddr4d_local_cal_fail)
	);

DE10PRO_SI5340A_CONFIG si5340a0_controller (
    .iCLK                   (CLK_50_B2C),
    .iRST_n                 (si5340_rstn_rr),
    .iStart                 (1'b0),
    .iXCVR0_REFCLK          (XCVR_REF_644M53125),
    .iXCVR1_REFCLK          (XCVR_REF_250M),
    .iMEM0_REFCLK           (MEM_REF_166M667),
    .iMEM1_REFCLK           (MEM_REF_166M667),
    .I2C_CLK                (SI5340A0_I2C_SCL),
    .I2C_DATA               (SI5340A0_I2C_SDA),
    .oPLL_I2C_ID_READ_ERROR (si5340a0_i2c_id_read_error),
    .oPLL_REG_CONFIG_DONE   (si5340a0_config_done)
);

DE10PRO_SI5340A_CONFIG si5340a1_controller (
    .iCLK                   (CLK_50_B2C),
    .iRST_n                 (si5340_rstn_rr),
    .iStart                 (1'b0),
    .iXCVR0_REFCLK          (XCVR_REF_644M53125),
    .iXCVR1_REFCLK          (XCVR_REF_644M53125),
    .iMEM0_REFCLK           (MEM_REF_166M667),
    .iMEM1_REFCLK           (MEM_REF_166M667),
    .I2C_CLK                (SI5340A1_I2C_SCL),
    .I2C_DATA               (SI5340A1_I2C_SDA),
    .oPLL_I2C_ID_READ_ERROR (si5340a1_i2c_id_read_error),
    .oPLL_REG_CONFIG_DONE   (si5340a1_config_done)
);

assign SI5340A0_RST_n = 1'b1;
assign SI5340A0_OE_n  = 1'b0;
assign SI5340A1_RST_n = 1'b1;
assign SI5340A1_OE_n  = 1'b0;

endmodule
