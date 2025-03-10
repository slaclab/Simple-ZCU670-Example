-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RfDataConverter Module
-------------------------------------------------------------------------------
-- This file is part of 'Simple-ZCU670-Example'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Simple-ZCU670-Example', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

library work;
use work.AppPkg.all;

library axi_soc_ultra_plus_core;
use axi_soc_ultra_plus_core.AxiSocUltraPlusPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RfDataConverter is
   generic (
      TPD_G            : time := 1 ns;
      AXIL_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- RF DATA CONVERTER Ports
      adcClkP         : in  slv(1 downto 0);
      adcClkN         : in  slv(1 downto 0);
      adcP            : in  slv(9 downto 0);
      adcN            : in  slv(9 downto 0);
      dacClkP         : in  slv(1 downto 0);
      dacClkN         : in  slv(1 downto 0);
      dacP            : out slv(7 downto 0);
      dacN            : out slv(7 downto 0);
      sysRefP         : in  sl;
      sysRefN         : in  sl;
      -- ADC/DAC Interface (dspClk domain)
      dspClk          : out sl;
      dspRst          : out sl;
      dspAdc          : out Slv256Array(1 downto 0);
      dspDac          : in  Slv256Array(1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType);
end RfDataConverter;

architecture mapping of RfDataConverter is

   component RfDataConverterIpCore
      port (
         clk_adc2        : out std_logic;
         dac0_clk_p      : in  std_logic;
         dac0_clk_n      : in  std_logic;
         clk_dac0        : out std_logic;
         s_axi_aclk      : in  std_logic;
         s_axi_aresetn   : in  std_logic;
         s_axi_awaddr    : in  std_logic_vector(17 downto 0);
         s_axi_awvalid   : in  std_logic;
         s_axi_awready   : out std_logic;
         s_axi_wdata     : in  std_logic_vector(31 downto 0);
         s_axi_wstrb     : in  std_logic_vector(3 downto 0);
         s_axi_wvalid    : in  std_logic;
         s_axi_wready    : out std_logic;
         s_axi_bresp     : out std_logic_vector(1 downto 0);
         s_axi_bvalid    : out std_logic;
         s_axi_bready    : in  std_logic;
         s_axi_araddr    : in  std_logic_vector(17 downto 0);
         s_axi_arvalid   : in  std_logic;
         s_axi_arready   : out std_logic;
         s_axi_rdata     : out std_logic_vector(31 downto 0);
         s_axi_rresp     : out std_logic_vector(1 downto 0);
         s_axi_rvalid    : out std_logic;
         s_axi_rready    : in  std_logic;
         irq             : out std_logic;
         sysref_in_p     : in  std_logic;
         sysref_in_n     : in  std_logic;
         vin2_01_p       : in  std_logic;
         vin2_01_n       : in  std_logic;
         vin2_23_p       : in  std_logic;
         vin2_23_n       : in  std_logic;
         vout00_p        : out std_logic;
         vout00_n        : out std_logic;
         vout01_p        : out std_logic;
         vout01_n        : out std_logic;
         m2_axis_aresetn : in  std_logic;
         m2_axis_aclk    : in  std_logic;
         m20_axis_tdata  : out std_logic_vector(191 downto 0);
         m20_axis_tvalid : out std_logic;
         m20_axis_tready : in  std_logic;
         m22_axis_tdata  : out std_logic_vector(191 downto 0);
         m22_axis_tvalid : out std_logic;
         m22_axis_tready : in  std_logic;
         s0_axis_aresetn : in  std_logic;
         s0_axis_aclk    : in  std_logic;
         s00_axis_tdata  : in  std_logic_vector(255 downto 0);
         s00_axis_tvalid : in  std_logic;
         s00_axis_tready : out std_logic;
         s01_axis_tdata  : in  std_logic_vector(255 downto 0);
         s01_axis_tvalid : in  std_logic;
         s01_axis_tready : out std_logic
         );
   end component;

   signal rfdcAdc   : Slv192Array(1 downto 0) := (others => (others => '0'));
   signal rfdcValid : slv(1 downto 0)         := (others => '0');
   signal rfdcDac   : Slv256Array(1 downto 0) := (others => (others => '0'));

   signal adc      : Slv192Array(1 downto 0) := (others => (others => '0'));
   signal adcValid : slv(1 downto 0)         := (others => '0');

   signal refClk   : sl := '0';
   signal axilRstL : sl := '0';

   signal rfdcClk  : sl := '0';
   signal rfdcRst  : sl := '1';
   signal rfdcRstL : sl := '0';

   signal dspClock  : sl := '0';
   signal dspReset  : sl := '1';
   signal dspResetL : sl := '0';

begin

   U_IpCore : RfDataConverterIpCore
      port map (
         -- Clock Ports
         clk_adc2      => open,
         dac0_clk_p    => dacClkP(0),
         dac0_clk_n    => dacClkN(0),
         clk_dac0      => refClk,
         -- AXI-Lite Ports
         s_axi_aclk    => axilClk,
         s_axi_aresetn => axilRstL,
         s_axi_awaddr  => axilWriteMaster.awaddr(17 downto 0),
         s_axi_awvalid => axilWriteMaster.awvalid,
         s_axi_awready => axilWriteSlave.awready,
         s_axi_wdata   => axilWriteMaster.wdata,
         s_axi_wstrb   => axilWriteMaster.wstrb,
         s_axi_wvalid  => axilWriteMaster.wvalid,
         s_axi_wready  => axilWriteSlave.wready,
         s_axi_bresp   => axilWriteSlave.bresp,
         s_axi_bvalid  => axilWriteSlave.bvalid,
         s_axi_bready  => axilWriteMaster.bready,
         s_axi_araddr  => axilReadMaster.araddr(17 downto 0),
         s_axi_arvalid => axilReadMaster.arvalid,
         s_axi_arready => axilReadSlave.arready,
         s_axi_rdata   => axilReadSlave.rdata,
         s_axi_rresp   => axilReadSlave.rresp,
         s_axi_rvalid  => axilReadSlave.rvalid,
         s_axi_rready  => axilReadMaster.rready,
         -- Misc. Ports
         irq           => open,
         sysref_in_p   => sysRefP,
         sysref_in_n   => sysRefN,
         -- ADC Ports
         vin2_01_p     => adcP(8),
         vin2_01_n     => adcN(8),
         vin2_23_p     => adcP(9),
         vin2_23_n     => adcN(9),
         -- DAC Ports
         vout00_p      => dacP(0),
         vout00_n      => dacN(0),
         vout01_p      => dacP(1),
         vout01_n      => dacN(1),

         -- ADC[9:8] AXI Stream Interface
         m2_axis_aresetn => rfdcRstL,
         m2_axis_aclk    => rfdcClk,
         m20_axis_tdata  => rfdcAdc(0),
         m20_axis_tvalid => rfdcValid(0),
         m20_axis_tready => '1',
         m22_axis_tdata  => rfdcAdc(1),
         m22_axis_tvalid => rfdcValid(1),
         m22_axis_tready => '1',
         -- DAC[1:0] AXI Stream Interface
         s0_axis_aresetn => dspResetL,
         s0_axis_aclk    => dspClock,
         s00_axis_tdata  => rfdcDac(0),
         s00_axis_tvalid => '1',
         s00_axis_tready => open,
         s01_axis_tdata  => rfdcDac(1),
         s01_axis_tvalid => '1',
         s01_axis_tready => open);

   U_Pll : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 2,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 3.255,    -- 307.2 MHz
         CLKFBOUT_MULT_G   => 4,        -- 1228.8 MHz = 4 x 307.2 MHz
         CLKOUT0_DIVIDE_G  => 3,        -- 409.6 MHz = 1228.8MHz/3
         CLKOUT1_DIVIDE_G  => 4)        -- 307.2 MHz = 1228.8MHz/4
      port map(
         -- Clock Input
         clkIn     => refClk,
         rstIn     => axilRst,
         -- Clock Outputs
         clkOut(0) => rfdcClk,
         clkOut(1) => dspClock,
         -- Reset Outputs
         rstOut(0) => rfdcRst,
         rstOut(1) => dspReset);

   axilRstL  <= not(axilRst);
   rfdcRstL  <= not(rfdcRst);
   dspResetL <= not(dspReset);

   dspClk <= dspClock;
   dspRst <= dspReset;

   process(rfdcClk)
   begin
      -- Help with making timing
      if rising_edge(rfdcClk) then
         adc      <= rfdcAdc   after TPD_G;
         adcValid <= rfdcValid after TPD_G;
      end if;
   end process;

   process(dspClock)
   begin
      -- Help with making timing
      if rising_edge(dspClock) then
         rfdcDac <= dspDac after TPD_G;
      end if;
   end process;

   U_Gearbox : entity axi_soc_ultra_plus_core.Ssr12ToSsr16Gearbox
      generic map (
         TPD_G    => TPD_G,
         NUM_CH_G => 2)
      port map (
         -- Slave Interface
         wrClk  => rfdcClk,
         wrData => adc,
         -- Master Interface
         rdClk  => dspClock,
         rdRst  => dspReset,
         rdData => dspAdc);

end mapping;
