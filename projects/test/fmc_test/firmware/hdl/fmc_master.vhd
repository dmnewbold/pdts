-- payload.vhd
--
-- Dave Newbold, February 2016

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_misc.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_top.all;

library unisim;
use unisim.VComponents.all;

entity fmc_test is
	port(
		ipb_clk: in std_logic;
		ipb_rst: in std_logic;
		ipb_in: in ipb_wbus;
		ipb_out: out ipb_rbus;
		nuke: out std_logic;
		soft_rst: out std_logic;
		userled: out std_logic;
		clk125: in std_logic;
		fmc_clk_p: in std_logic;
		fmc_clk_n: in std_logic;
		rec_clk_p: in std_logic;
		rec_clk_n: in std_logic;
		rec_d_p: in std_logic;
		rec_d_n: in std_logic;
		clk_out_p: out std_logic;
		clk_out_n: out std_logic;
		rj45_din_p: in std_logic;
		rj45_din_n: in std_logic;
		rj45_dout_p: out std_logic;
		rj45_dout_n: out std_logic;
		sfp_dout_p: out std_logic;
		sfp_dout_n: out std_logic;
		cdr_lol: in std_logic;
		cdr_los: in std_logic;
		sfp_los: in std_logic;
		sfp_tx_dis: out std_logic;
		sfp_flt: in std_logic;
		uid_scl: out std_logic;
		uid_sda: inout std_logic;
		sfp_scl: out std_logic;
		sfp_sda: inout std_logic;
		pll_scl: out std_logic;
		pll_sda: inout std_logic;
		pll_rstn: out std_logic;
		gpin_0_p: in std_logic;
		gpin_0_n: in std_logic;
		gpout_0_p: out std_logic;
		gpout_0_n: out std_logic;
		gpout_1_p: out std_logic;
		gpout_1_n: out std_logic		
	);

end fmc_test;

architecture rtl of fmc_test is

	signal ipbw: ipb_wbus_array(N_SLAVES - 1 downto 0);
	signal ipbr: ipb_rbus_array(N_SLAVES - 1 downto 0);
	signal ctrl: ipb_reg_v(0 downto 0);
	signal stat: ipb_reg_v(4 downto 0);
	signal rst, fmc_clk, rec_clk, rec_d, sfp_dout: std_logic;
	signal ctrl_chk_init, rst_fmc_clk, rst_rec_clk, chk_init, rec_d_r, p: std_logic;
	signal cyc_ctr, err_ctr: std_logic_vector(47 downto 0);
	signal zflag: std_logic;
	
	attribute IOB: string;
	attribute IOB of sfp_dout: signal is "TRUE";
	attribute IOB of rec_d_r: signal is "TRUE";
			
begin

-- ipbus address decode
		
	fabric: entity work.ipbus_fabric_sel
	generic map(
    	NSLV => N_SLAVES,
    	SEL_WIDTH => IPBUS_SEL_WIDTH
    )
    port map(
      ipb_in => ipb_in,
      ipb_out => ipb_out,
      sel => ipbus_sel_top(ipb_in.ipb_addr),
      ipb_to_slaves => ipbw,
      ipb_from_slaves => ipbr
    );

-- IO

	io: entity work.pdts_fmc_io
		port map(
			ipb_clk => ipb_clk,
			ipb_rst => ipb_rst,
			ipb_in => ipbw(N_SLV_IO),
			ipb_out => ipbr(N_SLV_IO),
			clk125 => clk125,
			soft_rst => soft_rst,
			nuke => nuke,
			rst => rst,
			cdr_lol => cdr_lol,
			cdr_los => cdr_los,
			sfp_los => sfp_los,
			sfp_tx_dis => sfp_tx_dis,
			sfp_flt => sfp_flt,
			userled => userled,
			fmc_clk_p => fmc_clk_p,
			fmc_clk_n => fmc_clk_n,
			fmc_clk => fmc_clk,
			rec_clk_p => rec_clk_p,
			rec_clk_n => rec_clk_n,
			rec_clk => rec_clk,
			rec_d_p => rec_d_p,
			rec_d_n => rec_d_n,
			rec_d => rec_d,
			clk_out_p => clk_out_p,
			clk_out_n => clk_out_n,
			rj45_din_p => rj45_din_p,
			rj45_din_n => rj45_din_n,
			rj45_dout_p => rj45_dout_p,
			rj45_dout_n => rj45_dout_n,
			sfp_dout => sfp_dout,
			sfp_dout_p => sfp_dout_p,
			sfp_dout_n => sfp_dout_n,
			uid_scl => uid_scl,
			uid_sda => uid_sda,
			sfp_scl => sfp_scl,
			sfp_sda => sfp_sda,
			pll_scl => pll_scl,
			pll_sda => pll_sda,
			pll_rstn => pll_rstn,
			gpin_0_p => gpin_0_p,
			gpin_0_n => gpin_0_n,
			gpout_0_p => gpout_0_p,
			gpout_0_n => gpout_0_n,
			gpout_1_p => gpout_1_p,
			gpout_1_n => gpout_1_n
		);
    
-- CSR

	csr: entity work.ipbus_ctrlreg_v
		generic map(
			N_CTRL => 1,
			N_STAT => 5
		)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(N_SLV_CSR),
			ipbus_out => ipbr(N_SLV_CSR),
			d => stat,
			q => ctrl
		);
		
	stat(0) <= X"0000000" & "000" & zflag;
	stat(1) <= cyc_ctr(31 downto 0);
	stat(2) <= X"0000" & cyc_ctr(47 downto 32);
	stat(3) <= err_ctr(31 downto 0);
	stat(4) <= X"0000" & err_ctr(47 downto 32);
	
	ctrl_chk_init <= ctrl(0)(0);
	
	fmc_clk_s: entity work.pdts_synchro
		port map(
			clk => ipb_clk,
			clks => fmc_clk,
			d(0) => rst,
			q(0) => rst_fmc_clk
		);
		
	rec_clk_s: entity work.pdts_synchro
		generic map(
			N => 2
		)
		port map(
			clk => ipb_clk,
			clks => rec_clk,
			d(0) => rst,
			d(1) => ctrl_chk_init,
			q(0) => rst_rec_clk,
			q(1) => chk_init
		);
		
-- PRBS
		
	prbs: entity work.prbs7_ser
		port map(
			clk => fmc_clk,
			rst => rst_fmc_clk,
			load => '0',
			d => '0',
			q => p
		);

	sfp_dout <= p when rising_edge(fmc_clk);

	rec_d_r <= rec_d when rising_edge(rec_clk);
	
	prbs_chk_sfp: entity work.prbs7_chk
		port map(
			clk => rec_clk,
			rst => rst_rec_clk,
			init => chk_init,
			d => rec_d_r,
			err_ctr => err_ctr,
			cyc_ctr => cyc_ctr,
			zflag => zflag
		);
		
end rtl;
