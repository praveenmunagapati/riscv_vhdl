-----------------------------------------------------------------------------
--! @file
--! @copyright Copyright 2015 GNSS Sensor Ltd. All right reserved.
--! @author    Sergey Khabarov - sergeykhbr@gmail.com
--! @brief     Testbench file for the SoC top-level implementation
------------------------------------------------------------------------------
--!
--! @page sim_tb_link Top-level simulation
--!
--! @par Test-bench example
--! Use file <b>work/tb/riscv_soc_tb.vhd</b> to run simulation scenario. You can
--! get the following time diagram after simulation of 2 ms interval.
--!
--! <img src="pics/soc_sim.png" alt="Simulating top"> 
--! @latexonly {\includegraphics[scale=0.75]{pics/soc_sim.png}} @endlatexonly
--!
--! @note Provided Firmware can detect RTL simulation target (see 
--!       <i>fw/boot/src/main.c</i> line 35) and can speed-up simulation
--!       by removing some delay and changing some parameters (UART speed for
--!       example).
--!
--! @par Running on FPGA
--! Supported FPGA:
--! <ul>
--!    <li>ML605 with Virtex6 FPGA using ISE 14.7 (default).</li>
--!    <li>KC705 with Kintex7 FPGA using Vivado 2015.4.</li>
--! </ul>
--! @warning <em><b>Switch ON DIP[0] (i_int_clkrf) to enable test mode because
--!          you most probably doesn't have RF front-end. Otherwise there 
--!          wouldn't be generated interrupts and, as result, no UART 
--!          output.</b></em>.

library ieee;
use ieee.std_logic_1164.all;
library std;
use std.textio.all;
library commonlib;
use commonlib.types_util.all;
library rocketlib;
--use rocketlib.types_rocket.all;

entity riscv_soc_tb is
  constant INCR_TIME : time := 3571 ps;--100 ns;--3571 ps;
end riscv_soc_tb;

architecture behavior of riscv_soc_tb is
  -- input/output signals:
  signal i_rst : std_logic := '1';
  signal i_sclk_p : std_logic;
  signal i_sclk_n : std_logic;
  signal i_clk_adc : std_logic := '0';
  signal i_int_clkrf : std_logic;
  signal i_dip : std_logic_vector(3 downto 1);
  signal o_led : std_logic_vector(7 downto 0);
  signal i_uart1_ctsn : std_logic := '0';
  signal i_uart1_rd : std_logic := '1';
  signal o_uart1_td : std_logic;
  signal o_uart1_rtsn : std_logic;
  
  signal i_gps_ld    : std_logic := '0';--'1';
  signal i_glo_ld    : std_logic := '0';--'1';
  signal o_max_sclk  : std_logic;
  signal o_max_sdata : std_logic;
  signal o_max_ncs   : std_logic_vector(1 downto 0);
  signal i_antext_stat   : std_logic := '0';
  signal i_antext_detect : std_logic := '0';
  signal o_antext_ena    : std_logic;
  signal o_antint_contr  : std_logic;

  signal o_emdc    : std_logic;
  signal io_emdio  : std_logic;
  signal i_rxd  : std_logic_vector(3 downto 0) := "0000";
  signal i_rxdv : std_logic := '0';
  signal o_txd  : std_logic_vector(3 downto 0);
  signal o_txdv : std_logic;

  signal uart_wr_str : std_logic;
  signal uart_instr : string(1 to 256);
  signal uart_busy : std_logic;

  signal adc_cnt : integer := 0;
  signal clk_cur: std_logic := '1';
  signal check_clk_bus : std_logic := '0';
  signal iClkCnt : integer := 0;
  signal iErrCnt : integer := 0;
  signal iErrCheckedCnt : integer := 0;
  signal iEdclCnt : integer := 0;
  
component riscv_soc is port 
( 
  i_rst     : in std_logic; -- button "Center"
  i_sclk_p  : in std_logic;
  i_sclk_n  : in std_logic;
  i_clk_adc : in std_logic;
  i_int_clkrf : in std_logic;
  i_dip     : in std_logic_vector(3 downto 1);
  o_led     : out std_logic_vector(7 downto 0);
  -- uart1
  i_uart1_ctsn : in std_logic;
  i_uart1_rd   : in std_logic;
  o_uart1_td   : out std_logic;
  o_uart1_rtsn : out std_logic;
  -- ADC samples
  i_gps_I  : in std_logic_vector(1 downto 0);
  i_gps_Q  : in std_logic_vector(1 downto 0);
  i_glo_I  : in std_logic_vector(1 downto 0);
  i_glo_Q  : in std_logic_vector(1 downto 0);
  -- rf front-end
  i_gps_ld    : in std_logic;
  i_glo_ld    : in std_logic;
  o_max_sclk  : out std_logic;
  o_max_sdata : out std_logic;
  o_max_ncs   : out std_logic_vector(1 downto 0);
  i_antext_stat   : in std_logic;
  i_antext_detect : in std_logic;
  o_antext_ena    : out std_logic;
  o_antint_contr  : out std_logic;
  i_gmiiclk_p : in    std_ulogic;
  i_gmiiclk_n : in    std_ulogic;
  o_egtx_clk  : out   std_ulogic;
  i_etx_clk   : in    std_ulogic;
  i_erx_clk   : in    std_ulogic;
  i_erxd      : in    std_logic_vector(3 downto 0);
  i_erx_dv    : in    std_ulogic;
  i_erx_er    : in    std_ulogic;
  i_erx_col   : in    std_ulogic;
  i_erx_crs   : in    std_ulogic;
  i_emdint    : in std_ulogic;
  o_etxd      : out   std_logic_vector(3 downto 0);
  o_etx_en    : out   std_ulogic;
  o_etx_er    : out   std_ulogic;
  o_emdc      : out   std_ulogic;
  io_emdio    : inout std_logic;
  o_erstn     : out   std_ulogic
);
end component;

component uart_sim is 
  generic (
    clock_rate : integer := 10
  ); 
  port (
    rst : in std_logic;
    clk : in std_logic;
    wr_str : in std_logic;
    instr : in string;
    td  : in std_logic;
    rtsn : in std_logic;
    rd  : out std_logic;
    ctsn : out std_logic;
    busy : out std_logic
  );
end component;

   -- Use '20150601_riscv' project to generate network nibbles in string format:
   --   Open grethaxi.cpp (line 855)
   --   Use methods sendEdclRead/sendEdclWrite and generate_tb_string.

   -- Message 1: Read npc register from debug port of RIVER CPU:
   --    edcl index = 0
   --    address = 0x80088000 | (33 << 3) = 0x80088108
   --    size = 2 x word32 = 8 bytes
   constant EDCL_MSG1_START : integer := 1000;
   constant EDCL_MSG1_LEN : integer := 114;
   constant EDCL_MSG1 : std_logic_vector(EDCL_MSG1_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb800000e100450000000029bd11000c8a00a00c8a00f07788556600a01655000000004000088018802a32c544";
   
   -- Message 2: Write CSR register mtimecmp to debug port of RIVER CPU:
   --    edcl index = 1
   --    address = 0x8008000 | (321 << 3)
   --    size = 8 bytes
   --    wdata = 0x8877665544332211
   constant EDCL_MSG2_START : integer := 2000;
   constant EDCL_MSG2_LEN : integer := 130;
   constant EDCL_MSG2 : std_logic_vector(EDCL_MSG2_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb80000062004500000000293e11000c8a00a00c8a00f07788556600217baf000000604000088091801122334455667788ec10d362";


   -- Message 3: Read 32 x words32 from ROM (romimage):
   --    edcl index = 2
   --    address = 0x00100000
   --    size = 32 x word32 = 256 bytes
   constant EDCL_MSG3_START : integer := 3000;
   constant EDCL_MSG3_LEN : integer := 114;
   constant EDCL_MSG3 : std_logic_vector(EDCL_MSG3_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb800000e100450000000029bd11000c8a00a00c8a00f07788556600a062e40000008004000001000048d5979f";
   
   -- Message 4: Read 20 x words32 from SRAM:
   --    edcl index = 3
   --    address = 0x10001450
   --    size = 20 x word32 = 80 bytes
   constant EDCL_MSG4_START : integer := 4000;
   constant EDCL_MSG4_LEN : integer := 114;
   constant EDCL_MSG4 : std_logic_vector(EDCL_MSG4_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb800000e100450000000029bd11000c8a00a00c8a00f07788556600a0a1a0000000c082000100410560799d79";
   
   -- Message 5: Read 10 x words32 from SRAM:
   --    edcl index = 4
   --    address = 0x10001D60
   --    size = 10 x word32 = 40 bytes
   constant EDCL_MSG5_START : integer := 5000-22;
   constant EDCL_MSG5_LEN : integer := 114;
   constant EDCL_MSG5 : std_logic_vector(EDCL_MSG5_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb800000e100450000000029bd11000c8a00a00c8a00f07788556600a0426f0000000141000100d106e3d35cdc";

   -- Message 6: Write 8 x 64-bits (64 bytes) into SRAM:
   --    edcl index = 5
   --    address = 0x10030d40
   --    uint64_t wdata6[8] = {0x2222222211111111ull, 0x4444444433333333ull, 0x6666666655555555ull, 0x8888888877777777ull,
   --                          0xaaaaaaaa99999999ull, 0xccccccccbbbbbbbbull, 0xffffffffeeeeeeeeull, 0xcafecafebeefbeefull};
   --    size = 64 bytes
   constant EDCL_MSG6_START : integer := 6000;
   constant EDCL_MSG6_LEN : integer := 242;
   constant EDCL_MSG6 : std_logic_vector(EDCL_MSG6_LEN*4-1 downto 0) := 
   X"5d207098001032badcacefebeb800000e500450000000039b111000c8a00a00c8a00f07788556600a4705b0000006102000130d004111111112222222233333333444444445555555566666666777777778888888899999999aaaaaaaabbbbbbbbcccccccceeeeeeeefffffffffeebfeebefacefacc3875a17";   

   constant ETH_ENABLE : std_logic := '0';
begin


  -- Process of reading
  procReadingFile : process
    variable clk_next: std_logic;
  begin

    wait for INCR_TIME;
    if (adc_cnt + 26000000) >= 70000000 then
      adc_cnt <= (adc_cnt + 26000000) - 70000000;
      i_clk_adc <= not i_clk_adc;
    else
      adc_cnt <= (adc_cnt + 26000000);
    end if;

    while true loop
      clk_next := not clk_cur;
      if (clk_next = '1' and clk_cur = '0') then
        check_clk_bus <= '1';
      elsif (clk_next = '0' and clk_cur = '1') then
        if iClkCnt >= EDCL_MSG1_START and iClkCnt < (EDCL_MSG1_START + EDCL_MSG1_LEN) then
           i_rxd <= EDCL_MSG1(4*(EDCL_MSG1_LEN - (iClkCnt-EDCL_MSG1_START))-1 downto 4*(EDCL_MSG1_LEN - (iClkCnt-EDCL_MSG1_START))-4);
           i_rxdv <= ETH_ENABLE;
        elsif iClkCnt >= EDCL_MSG2_START and iClkCnt < (EDCL_MSG2_START + EDCL_MSG2_LEN) then
           i_rxd <= EDCL_MSG2(4*(EDCL_MSG2_LEN - (iClkCnt-EDCL_MSG2_START))-1 downto 4*(EDCL_MSG2_LEN - (iClkCnt-EDCL_MSG2_START))-4);
           i_rxdv <= ETH_ENABLE;
        elsif iClkCnt >= EDCL_MSG3_START and iClkCnt < (EDCL_MSG3_START + EDCL_MSG3_LEN) then
           i_rxd <= EDCL_MSG3(4*(EDCL_MSG3_LEN - (iClkCnt-EDCL_MSG3_START))-1 downto 4*(EDCL_MSG3_LEN - (iClkCnt-EDCL_MSG3_START))-4);
           i_rxdv <= ETH_ENABLE;
        elsif iClkCnt >= EDCL_MSG4_START and iClkCnt < (EDCL_MSG4_START + EDCL_MSG4_LEN) then
           i_rxd <= EDCL_MSG4(4*(EDCL_MSG4_LEN - (iClkCnt-EDCL_MSG4_START))-1 downto 4*(EDCL_MSG4_LEN - (iClkCnt-EDCL_MSG4_START))-4);
           i_rxdv <= ETH_ENABLE;
        elsif iClkCnt >= EDCL_MSG5_START and iClkCnt < (EDCL_MSG5_START + EDCL_MSG5_LEN) then
           i_rxd <= EDCL_MSG5(4*(EDCL_MSG5_LEN - (iClkCnt-EDCL_MSG5_START))-1 downto 4*(EDCL_MSG5_LEN - (iClkCnt-EDCL_MSG5_START))-4);
           i_rxdv <= ETH_ENABLE;
        elsif iClkCnt >= EDCL_MSG6_START and iClkCnt < (EDCL_MSG6_START + EDCL_MSG6_LEN) then
           i_rxd <= EDCL_MSG6(4*(EDCL_MSG6_LEN - (iClkCnt-EDCL_MSG6_START))-1 downto 4*(EDCL_MSG6_LEN - (iClkCnt-EDCL_MSG6_START))-4);
           i_rxdv <= ETH_ENABLE;
        else
           i_rxd <= "0000";
           i_rxdv <= '0';
        end if;
      end if;

      wait for 1 ps;
      check_clk_bus <= '0';
      clk_cur <= clk_next;

      wait for INCR_TIME;
      if clk_cur = '1' then
        iClkCnt <= iClkCnt + 1;
      end if;
      if (adc_cnt + 26000000) >= 70000000 then
        adc_cnt <= (adc_cnt + 26000000) - 70000000;
        i_clk_adc <= not i_clk_adc;
      else
        adc_cnt <= (adc_cnt + 26000000);
      end if;

    end loop;
    report "Total clocks checked: " & tost(iErrCheckedCnt) & " Errors: " & tost(iErrCnt);
    wait for 1 sec;
  end process procReadingFile;


  i_sclk_p <= clk_cur;
  i_sclk_n <= not clk_cur;

  procSignal : process (i_sclk_p, iClkCnt)

  begin
    if rising_edge(i_sclk_p) then
      
      --! @note to make sync. reset  of the logic that are clocked by
      --!       htif_clk which is clock/512 by default.
      if iClkCnt = 15 then
        i_rst <= '0';
      end if;
    end if;
  end process procSignal;

  i_dip <= "000";
  i_int_clkrf <= '1';

  udatagen0 : process (i_sclk_n, iClkCnt)
  begin
    if rising_edge(i_sclk_n) then
        uart_wr_str <= '0';
        if iClkCnt = 82000 then
           uart_wr_str <= '1';
           uart_instr(1 to 4) <= "ping";
           uart_instr(5) <= cr;
           uart_instr(6) <= lf;
        elsif iClkCnt = 108000 then
           uart_wr_str <= '1';
           uart_instr(1 to 3) <= "pnp";
           uart_instr(4) <= cr;
           uart_instr(5) <= lf;
        end if;
    end if;
  end process;


  uart0 : uart_sim generic map (
    clock_rate => 2*20
  ) port map (
    rst => i_rst,
    clk => i_sclk_p,
    wr_str => uart_wr_str,
    instr => uart_instr,
    td  => o_uart1_td,
    rtsn => o_uart1_rtsn,
    rd  => i_uart1_rd,
    ctsn => i_uart1_ctsn,
    busy => uart_busy
  );


  -- signal parsment and assignment
  tt : riscv_soc port map
  (
    i_rst     => i_rst,
    i_sclk_p  => i_sclk_p,
    i_sclk_n  => i_sclk_n,
    i_clk_adc => '0',--i_clk_adc,
    i_int_clkrf => i_int_clkrf,
    i_dip     => i_dip,
    o_led     => o_led,
    i_uart1_ctsn => i_uart1_ctsn,
    i_uart1_rd   => i_uart1_rd,
    o_uart1_td   => o_uart1_td,
    o_uart1_rtsn => o_uart1_rtsn,
    i_gps_I  => "01",
    i_gps_Q  => "11",
    i_glo_I  => "11",
    i_glo_Q  => "01",
    i_gps_ld    => i_gps_ld,
    i_glo_ld    => i_glo_ld,
    o_max_sclk  => o_max_sclk,
    o_max_sdata => o_max_sdata,
    o_max_ncs   => o_max_ncs,
    i_antext_stat   => i_antext_stat,
    i_antext_detect => i_antext_detect,
    o_antext_ena    => o_antext_ena,
    o_antint_contr  => o_antint_contr,
    i_gmiiclk_p => '0',
    i_gmiiclk_n => '1',
    o_egtx_clk  => open,
    i_etx_clk   => i_sclk_p,
    i_erx_clk   => i_sclk_p,
    i_erxd      => i_rxd,
    i_erx_dv    => i_rxdv,
    i_erx_er    => '0',
    i_erx_col   => '0',
    i_erx_crs   => '0',
    i_emdint    => '0',
    o_etxd      => o_txd,
    o_etx_en    => o_txdv,
    o_etx_er    => open,
    o_emdc      => o_emdc,
    io_emdio    => io_emdio,
    o_erstn     => open
 );

  procCheck : process (i_rst, check_clk_bus)
  begin
    if rising_edge(check_clk_bus) then
      if i_rst = '0' then
        iErrCheckedCnt <= iErrCheckedCnt + 1;
      end if;
    end if;
  end process procCheck;

end;
