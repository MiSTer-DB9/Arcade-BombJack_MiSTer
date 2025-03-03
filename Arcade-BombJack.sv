//============================================================================
//  Arcade: Bomb Jack
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
output	  USER_OSD,
output  [1:0] USER_MODE,
input	[7:0] USER_IN,
output	[7:0] USER_OUT,
input	OSD_STATUS
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;


wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[62],status[63],status[61]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6]; // Start + C activate OSD


assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;

wire [1:0] ar = status[22:21];

assign VIDEO_ARX = (!ar) ? ((status[2])  ? 12'd2560 : 12'd2191) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2])  ? 12'd2191 : 12'd2560) : 12'd0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXXXXXXXXXX XXX XXXXXXX XXXX

`include "build_id.v" 
localparam CONF_STR = {
	"A.BMBJCK;;",
	"H0OLM,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
"-;",
	"oUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"oT,UserIO Players, 1 Player,2 Players;",
"-;",
	"ON,Flip Screen,Off,On;",
	"O[6],Game Speed,Native,60Hz;",
	"O[31:28],CRT H adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"O[35:32],CRT V adjust,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",
	"P1,DIP Switches;",
	"P1O7,Demo Sounds,On,Off;",
	"P1O89,Lives,3,4,5,2;",
	"P1OAB,Bonus,500k,750k;",
	"P1OC,Cabinet,Upright,Cocktail;",
	"P1ODE,Enemy num & speed,Easy,Medium,Hard,Insane;",
	"P1OIJ,Bird Speed,Easy,Medium,Hard,Insane;",
	"P1OFH,Bonus Life,None,Every 100k,Every 30k,50k only,100k only,50k and 100k,100k and 300k,50k and 100k and 300k;",
"-;",
	"H1OR,Autosave Hiscores,Off,On;",
	"P2,Pause options;",
	"P2OP,Pause when OSD is open,On,Off;",
	"P2OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Jump,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire pll_locked;
wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 48
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(pll_locked)
);

wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

//Reconfigure PLL to apply an overclock to bring video timings in spec for 60Hz VSync
pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg overclock = 0, overclock2 = 0;
	reg [2:0] state = 0;
	reg overclock_r;

	overclock <= status[6];
	overclock2 <= overclock;

	cfg_write <= 0;
	if(overclock2 == overclock && overclock2 != overclock_r) begin
		state <= 1;
		overclock_r <= overclock2;
	end

	if(!cfg_waitrequest) begin
		if(state)
			state <= state + 1'd1;
		case(state)
			1: begin
				cfg_address <= 0;
				cfg_data <= 0;
				cfg_write <= 1;
			end
			5: begin
				cfg_address <= 7;
				cfg_data <= overclock_r ? 3221912667 : 2748778984;
				cfg_write <= 1;
			end
			7: begin
				cfg_address <= 2;
				cfg_data <= 0;
				cfg_write <= 1;
			end
		endcase
	end
end

///////////////////////////////////////////////////

wire [63:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire  [7:0]	ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joystick_0_USB, joystick_1_USB;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

// CO S2 S1 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[4:0]} : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[4:0]} : joydb_1ena ? joystick_0_USB : joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joy_raw(joydb_1[5:0])
);

wire no_rotate = status[2] | direct_video;

wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];

wire m_up_2     = joy[3];
wire m_down_2   = joy[2];
wire m_left_2   = joy[1];
wire m_right_2  = joy[0];
wire m_fire_2  = joy[4];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin   = joy[7];
wire m_pause  = joy[8];

// PAUSE SYSTEM
wire pause_cpu;
wire [11:0] rgb_out;
pause #(4,4,4,48) pause
(
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge clk_sys) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

wire rotate_ccw = 0;
wire flip = 0;
wire video_rotated;

screen_rotate screen_rotate (.*);

wire [3:0] hs_offset = status[31:28];
wire [3:0] vs_offset = status[35:32];
hvsync_gen #(.HS_POS(32), .VS_POS(13)) hvsync_gen
(
	.clk(CLK_VIDEO),
	.ce_pix(ce_pix),
	.hblank(hblank),
	.vblank(vblank),
	.hs_offset(hs_offset),
	.vs_offset(vs_offset),

	.hsync_o(hs),
	.vsync_o(vs)
);

arcade_video #(270,12) arcade_video
(
        .*,

        .clk_video(clk_sys),

        .RGB_in(rgb_out),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


wire [7:0] audio;
assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

wire reset;
assign reset = RESET | status[0] | ioctl_download | buttons[1];
wire rom_download = ioctl_download && !ioctl_index;

wire clk_6M;
bombjack_top bombjack_top
(
	.reset(reset),

	.clk_48M(clk_sys),
	.clk_6M(clk_6M),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.p1_start(m_start1),
	.p1_coin(m_coin),
	.p1_jump(m_fire),
	.p1_down(m_down),
	.p1_up(m_up),
	.p1_left(m_left),
	.p1_right(m_right),

	.p2_start(m_start2),
	.p2_coin(m_coin),
	.p2_jump(m_fire_2),
	.p2_down(m_down_2),
	.p2_up(m_up_2),
	.p2_left(m_left_2),
	.p2_right(m_right_2),

	.SW_DEMOSOUNDS(~status[7]),
	.SW_CABINET(~status[12]),
	.SW_LIVES(status[9:8]),
	.SW_ENEMIES(status[14:13]),
	.SW_BIRDSPEED(status[19:18]),
	.SW_BONUS(status[17:15]),

	.VGA_R(r),
	.VGA_G(g),
	.VGA_B(b),
//	.VGA_HS(hs),
//	.VGA_VS(vs),
	.O_VBLANK(vblank),
	.O_HBLANK(hblank),

	.audio(audio),

	.pause(pause_cpu),

	.hs_address(hs_address),
	.hs_data_out(hs_data_out),
	.hs_data_in(hs_data_in),
	.hs_write(hs_write),
	.flip_screen(status[23])
);

// HISCORE SYSTEM
// --------------

wire [15:0] hs_address;
wire [7:0] hs_data_in;
wire [7:0] hs_data_out;
wire hs_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(4),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write),
	.ram_intent_read(),
	.ram_intent_write(),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);

endmodule
