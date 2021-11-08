----------------------------------------------------------------------------------
-- Created by: GIUSEPPE CARRUBBA / NICOL� BIANCO
-- Create Date: 23.09.2021
-- Module Name: TB_controller
-- Project Name: Lightweight cipher
-- Version: 1.0
-- Additional Comments: 
----------------------------------------------------------------------------------
--  ******************************************************************************
--  * File Name          : FPGA_testbench.vhd
--  * Description        : Testbench for the IP Manager architecture
--  ******************************************************************************
--  *
--  * Copyright ? 2016-present Blu5 Group <https://www.blu5group.com>
--  *
--  * This library is free software; you can redistribute it and/or
--  * modify it under the terms of the GNU Lesser General Public
--  * License as published by the Free Software Foundation; either
--  * version 3 of the License, or (at your option) any later version.
--  *
--  * This library is distributed in the hope that it will be useful,
--  * but WITHOUT ANY WARRANTY; without even the implied warranty of
--  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  * Lesser General Public License for more details.
--  *
--  * You should have received a copy of the GNU Lesser General Public
--  * License along with this library; if not, see <https://www.gnu.org/licenses/>.
--  *
--  ******************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.CONSTANTS.all;

entity FPGA_testbench is
end FPGA_testbench;

architecture test of FPGA_testbench is 

	-- TIME CONSTANTS (COMING FROM SETTINGS OF SOFTWARE)
	constant HCLK_PERIOD 		 : time    := 5555 ps; -- 180 MHz
	constant PRESCALER			 : integer := 3;
	constant FPGA_CLK_PERIOD	 : time    := HCLK_PERIOD*PRESCALER;
	constant ADDRESS_SETUP_TIME	 : integer := 6;
	constant DATA_SETUP_TIME	 : integer := 6;	
		
	-- CONSTANTS FOR BETTER DEFINING CONTROL WORD TO BE WRITTEN IN ROW_0
	constant OPCODE_VOID    			    : std_logic_vector(OPCODE_SIZE-1 downto 0) := "000000";
	constant CONF_OPEN_TRANSACTION_INTMODE  : std_logic_vector(2 downto 0) := "101";
	constant CONF_CLOSE_TRANSACTION_INTMODE : std_logic_vector(2 downto 0) := "100";
	constant CONF_OPEN_TRANSACTION_POLMODE  : std_logic_vector(2 downto 0) := "001";
	constant CONF_CLOSE_TRANSACTION_POLMODE : std_logic_vector(2 downto 0) := "000";
	constant CONF_OPEN_TRANSACTION_ACK      : std_logic_vector(2 downto 0) := "111";
	constant CONF_CLOSE_TRANSACTION_ACK     : std_logic_vector(2 downto 0) := "110";
		
	-- FPGA INTERFACE SIGNALS
	signal hclk		 : std_logic := '0';	
	signal fpga_clk  : std_logic := '0';
	signal reset     : std_logic := '0';
	signal data      : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => 'Z');
	signal address   : std_logic_vector(ADD_WIDTH-1 downto 0)  := (others => 'Z');
	signal noe		 : std_logic := '0';
	signal nwe		 : std_logic := '1';
	signal ne1		 : std_logic := '1';
	signal interrupt : std_logic;
        --Memory
	type memory_128 is array (15 downto 0) of std_logic_vector(15 downto 0);
	signal result_array : memory_128 := (others=>(others=>'0')); 
	signal counter : integer := 0;
begin
 
  
 
   UUT: entity work.TOP_ENTITY
   	generic map(
   		ADDSET => ADDRESS_SETUP_TIME/PRESCALER,
   		DATAST => DATA_SETUP_TIME/PRESCALER
   	)
   	port map(
   		cpu_fpga_bus_a   => address,
   		cpu_fpga_bus_d   => data,
   		cpu_fpga_bus_noe => noe,
   		cpu_fpga_bus_nwe => nwe,
   		cpu_fpga_bus_ne1 => ne1,
   		cpu_fpga_clk     => fpga_clk,
   		cpu_fpga_int_n   => interrupt,
   		cpu_fpga_rst     => reset
   	);
 
 
 
   pll_osc : process
   begin
		hclk <= '1';
		wait for HCLK_PERIOD/2;
		hclk <= '0';
		wait for HCLK_PERIOD/2;		
	end process;
	
	
	
	fpga_osc : process
	begin
		fpga_clk <= '1';
		wait for FPGA_CLK_PERIOD/2;
		fpga_clk <= '0';
		wait for FPGA_CLK_PERIOD/2;
	end process;
	
	
	
	reset <= '0', '1' after HCLK_PERIOD*2*PRESCALER, '0' after HCLK_PERIOD*4*PRESCALER;
	
	
	
	stimuli: process
		
		-- RESULT OF THE READING PROCEDURE
		variable result : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
		
		-- R/W PROCEDURES EXECUTED BY THE MASTER (CPU THROUGH FMC) 
		procedure write(w_addr : in std_logic_vector(ADD_WIDTH-1 downto 0);
						w_data : in std_logic_vector(DATA_WIDTH-1 downto 0)) is
		begin
			wait for 15*HCLK_PERIOD;
			ne1 <= '0';
			noe <= '1';
			nwe <= '1';
			address <= w_addr;
			wait for ADDRESS_SETUP_TIME*HCLK_PERIOD;
			nwe <= '0';
			data <= w_data;
			wait for DATA_SETUP_TIME*HCLK_PERIOD;
			nwe <= '1';
			wait for HCLK_PERIOD;
			ne1 <= '1';
			noe <= '0';
		end write;
	
		procedure read(r_addr : in std_logic_vector(ADD_WIDTH-1 downto 0)) is
		begin
			wait for 15*HCLK_PERIOD;
			ne1 <= '0';
			noe <= '1';
			nwe <= '1';
			data <= (others => 'Z');
			address <= r_addr;
			wait for ADDRESS_SETUP_TIME*HCLK_PERIOD;
			noe <= '0'; 
			wait for  DATA_SETUP_TIME*HCLK_PERIOD;
			ne1 <= '1';
			noe <= '1';
			result := data;
		end read;
		

		
	begin
	   
		wait for HCLK_PERIOD*24; -- random number of cc before starting
				
--		--Init, encrypt 0
		
		write("000000", "100000" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
		--Key (not swapped)
		write("000001", x"def0"); --1
		write("000010", x"9abc"); --2
		write("000011", x"5678"); --3
		write("000100", x"1234"); --4
		write("000101", x"cdef"); --5
		write("000110", x"89ab"); --6
		write("000111", x"4567"); --7
		write("001000", x"0123"); --8
		--IV (not swapped)
		write("001001", x"5678"); --9
		write("001010", x"1234"); --10
		write("001011", x"cdef"); --11
		write("001100", x"89ab"); --12
		write("001101", x"4567"); --13
		write("001110", x"0123"); --14
		--Length msg || AD = 0x08 || 0x02 
		write("010001", x"0e04"); --17
		--AD
		write("010010", x"abcd"); --18
		write("010011", x"0011"); --19
		--Padding for AD
		
		
		--MSG
		write("011100", x"3333"); --28
		write("011101", x"2222"); --29
		write("011110", x"1111"); --30
		write("011111", x"dddd"); --31
		write("100000", x"cccc"); --32
		write("100001", x"bbbb"); --33
		write("100010", x"aaaa"); --34
		--write("100011", x"eeee"); --35
		--write("100100", x"0021"); --36
		--write("100101", x"6e65"); --37
		--write("100110", x"616f"); --38
		--write("100111", x"dddd"); --39
		--Padding for MSG
		
		--Polling word
 		write("111111", (others => '0'));
		read("111111");
 		while result /= x"FFFF" loop
 			read("111111");
 		end loop;
		
 		--CT
 		read("011100"); result_array(0) <= result; --28  		
		read("011101"); result_array(1) <= result;--29
 		read("011110"); result_array(2) <= result;--30
 		read("011111"); result_array(3) <= result;--31
		read("100000"); result_array(4) <= result;--32
 		read("100001"); result_array(5) <= result;--33
 		read("100010"); result_array(6) <= result;--34
 		read("100011"); result_array(7) <= result;--35
 		--MAC
 		read("101000"); result_array(8) <= result;--40
 		read("101001"); result_array(9) <= result;--41
 		read("101010"); result_array(10) <= result;--42
 		--read("101011"); result_array(11) <= result;--43
		
		write("111111", (others => '0'));
        write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");
		
--		--Next, encrypt 1
		
		-- write("000000", "100001" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
		-- --Lenght (not swapped)
		-- write("000001", x"1800"); --1
		-- --MSG
		-- write("000010", x"0021"); --2
		-- write("000011", x"6e65"); --3
		-- write("000100", x"616f"); --4
		-- write("000101", x"cccc"); --5
		-- write("000110", x"0021"); --6
		-- write("000111", x"6e65"); --7
		-- write("001000", x"616f"); --8
		-- write("001001", x"bbbb"); --9
		-- write("001010", x"0021"); --10
		-- write("001011", x"6e65"); --11
		-- write("001100", x"616f"); --12
		-- write("001101", x"aaaa"); --13

		-- --Polling word
 		-- write("111111", (others => '0'));
		-- read("111111");
 		-- while result /= x"FFFF" loop
 		-- 	read("111111");
 		-- end loop;
		
 		-- --CT
 		-- read("000010"); result_array(0) <= result; --2	
		-- read("000011"); result_array(1) <= result;--3
 		-- read("000100"); result_array(2) <= result;--4
 		-- read("000101"); result_array(3) <= result;--5
		-- read("000110"); result_array(4) <= result;--6
 		-- read("000111"); result_array(5) <= result;--7
 		-- read("001000"); result_array(6) <= result;--8
 		-- read("001001"); result_array(7) <= result;--9
 		-- --MAC
 		-- read("001010"); result_array(8) <= result;--10
 		-- read("001011"); result_array(9) <= result;--11
 		-- read("001100"); result_array(10) <= result;--12
 		-- read("001101"); result_array(11) <= result;--13
		
		-- write("111111", (others => '0'));
        -- write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");

		
--------------------------------------------------------------------------------------------------------------------------		
-- 		Decrypt, init
	 	write("000000", "100010" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
				 
	 	--Key (not swapped)
	 	write("000001", x"def0"); --1
	 	write("000010", x"9abc"); --2
	 	write("000011", x"5678"); --3
	 	write("000100", x"1234"); --4
	 	write("000101", x"cdef"); --5
	 	write("000110", x"89ab"); --6
	 	write("000111", x"4567"); --7
	 	write("001000", x"0123"); --8
	 	--IV (not swapped)
	 	write("001001", x"5678"); --9
	 	write("001010", x"1234"); --10
	 	write("001011", x"cdef"); --11
	 	write("001100", x"89ab"); --12
	 	write("001101", x"4567"); --13
	 	write("001110", x"0123"); --14
	 	                          --15
	 	--Two of padding          -16
		
	 	--Length ct || AD = 0x08 || 0x02 
	 	write("010001", x"0e04");
	 	--AD
	 	write("010010", x"abcd"); --18
		write("010011", x"0011"); --19

		--CT
        write("011100", x"51c0"); --28
	 	write("011101", x"51a6"); --29
	 	write("011110", x"1f37"); --30
	 	write("011111", x"2a9c"); --31
		write("100000", x"6c36"); --32
	 	write("100001", x"6448"); --33
	 	write("100010", x"0062"); --34
	 	write("100011", x"0968"); --35
		write("100100", x"0d07"); --36		
		write("100101", x"b888"); --37
		write("100110", x"5a1e"); --38
		--write("100111", x"0000"); --39
		--MAC
		--write("101000", x"0968"); --40
		--write("101001", x"b7ac"); --41
		--write("101010", x"c902"); --42
		--write("101011", x"c2ad"); --43

		
		--Wait for polling
		--Polling word
 		write("111111", (others => '0'));
		read("111111");
 		while result /= x"FFFF" loop
 			read("111111");
 		end loop;
		write("111111", (others => '0'));
		
		--CT
 		read("011100"); result_array(0) <= result; --28  		
		read("011101"); result_array(1) <= result;--29
 		read("011110"); result_array(2) <= result;--30
 		read("011111"); result_array(3) <= result;--31
		read("100000"); result_array(4) <= result;--32
 		read("100001"); result_array(5) <= result;--33
 		read("100010"); result_array(6) <= result;--34
 		--read("100011"); result_array(7) <= result;--35
		--read("100100"); result_array(8) <= result;--36
		--read("100101"); result_array(9) <= result;--37
		--read("100110"); result_array(10) <= result;--38
		--read("100111"); result_array(11) <= result;--39
		
		report "End of transaction";

	 	write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");


	-- 	-- 		Decrypt, next
	-- 	write("000000", "100011" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
				 
	-- 	--Key (not swapped)
	-- 	write("000001", x"1800"); --1
	-- 	write("000010", x"143c"); --2
	-- 	write("000011", x"7080"); --3
	-- 	write("000100", x"1784"); --4
	-- 	write("000101", x"7444"); --5
	-- 	write("000110", x"2616"); --6
	-- 	write("000111", x"dd14"); --7
	-- 	write("001000", x"6347"); --8
	-- 	write("001001", x"b3d3"); --9
	-- 	write("001010", x"ab27"); --10
	-- 	write("001011", x"3b90"); --11
	-- 	write("001100", x"1057"); --12
	-- 	write("001101", x"1cc4"); --13
	-- 	write("001110", x"a45e"); --14
	-- 	write("001111", x"8660"); --15
	-- 	write("010000", x"4ef7"); --16
	-- 	write("010001", x"6a8c"); --17
	   

	--    --Wait for polling
	--    --Polling word
	-- 	write("111111", (others => '0'));
	--    read("111111");
	-- 	while result /= x"FFFF" loop
	-- 		read("111111");
	-- 	end loop;
	--    write("111111", (others => '0'));
	   
	--    --CT
	-- 	read("011100"); result_array(0) <= result; --28  		
	--    read("011101"); result_array(1) <= result;--29
	-- 	read("011110"); result_array(2) <= result;--30
	-- 	read("011111"); result_array(3) <= result;--31
	--    read("100000"); result_array(4) <= result;--32
	-- 	read("100001"); result_array(5) <= result;--33
	-- 	read("100010"); result_array(6) <= result;--34
	-- 	read("100011"); result_array(7) <= result;--35
	--    read("100100"); result_array(8) <= result;--36
	--    read("100101"); result_array(9) <= result;--37
	--    read("100110"); result_array(10) <= result;--38
	--    read("100111"); result_array(11) <= result;--39
	   
	--    report "End of transaction";

	-- 	write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");
------------------------------------------------------------------------------------------------------------
	wait;
	end process stimuli;
		
end Test;