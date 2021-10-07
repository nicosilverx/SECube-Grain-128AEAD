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

--key:	
--iv:	


-- --		--Init, encrypt 0
 		write("000000", "100000" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
 		--Key (not swapped)
 		write("000001", x""); --1
 		write("000010", x""); --2
 		write("000011", x""); --3
 		write("000100", x""); --4
 		write("000101", x""); --5
 		write("000110", x""); --6
 		write("000111", x""); --7
 		write("001000", x""); --8
 		--IV (not swapped)
 		write("001001", x""); --9
 		write("001010", x""); --10
 		write("001011", x""); --11
 		write("001100", x""); --12
 		write("001101", x""); --13
 		write("001110", x""); --14
 		--Length msg || AD = 0x08 || 0x02 
 		write("010001", x""); --17
 		--AD
 		write("010010", x""); --18
 		--write("010011", x"1111"); --18
 		--Padding for AD
		
		
 		--MSG
 		write("011100", x""); --28
 		write("011101", x""); --29
 		write("011110", x""); --30
 		write("011111", x""); --31 
		write("100000", x""); --31
		write("100001", x""); --31
		write("100010", x""); --31
		write("100011", x""); --31

 		--Polling word
 		write("111111", (others => '0'));
 		while result = x"0000" loop
 			read("111111");
 		end loop;
 		--CT
 		read("011100"); --28
 		read("011101"); --29
 		read("011110"); --30
 		read("011111"); --31
 		--MAC
 		read("101000"); --40
 		read("101001"); --41
 		read("101010"); --42
 		read("101011"); --43
		
 		write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");
		
 		result := (others=>'0');
 		wait for 60*HCLK_PERIOD;
-- --		--
-- --		--
-- --		--    Encrypt 1, second part of the message
-- --		--
-- --		--
		
-- 		write("000000", "100001" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
-- 		--Length msg || AD = 0x08 || 0x02 
-- 		write("000001", x"0800"); --1
-- 		--MSG
-- 		write("000010", x"2121"); --2
-- 		write("000011", x"6e65"); --3
-- 		write("000100", x"616f"); --4
-- 		write("000101", x"6369"); --5
-- 		--Padding for MSG
		
-- 		--Polling word
-- 		write("111111", (others => '0'));
-- 		while result = x"0000" loop
-- 			read("111111");
-- 		end loop;
-- 		--CT
-- 		read("000010"); --2
-- 		read("000011"); --3
-- 		read("000100"); --4
-- 		read("000101"); --5
-- 		--MAC
-- 		read("000110"); --6
-- 		read("000111"); --7
-- 		read("001000"); --8
-- 		read("001001"); --9
		
-- 		write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");
-- 		result := (others=>'0');
-- 		wait for 60*HCLK_PERIOD;
--------------------------------------------------------------------------------------------------------------------------		
-- 		Decrypt, init
--		write("000000", "100010" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
--		
--		--Key (not swapped)
--		write("000001", x"def0"); --1
--		write("000010", x"9abc"); --2
--		write("000011", x"5678"); --3
--		write("000100", x"1234"); --4
--		write("000101", x"cdef"); --5
--		write("000110", x"89ab"); --6
--		write("000111", x"4567"); --7
--		write("001000", x"0123"); --8
--		--IV (not swapped)
--		write("001001", x"5678"); --9
--		write("001010", x"1234"); --10
--		write("001011", x"cdef"); --11
--		write("001100", x"89ab"); --12
--		write("001101", x"4567"); --13
--		write("001110", x"0123"); --14
--		                          --15
--		--Two of padding          -16
--		
--		--Length ct || AD = 0x08 || 0x02 
--		write("010001", x"0802");
--		--AD
--		write("010010", x"1111"); --18
--		--CT : 475f cba7 b196 81db 31e4 dcfe abe4 d624
--        write("011100", x"81db"); --28
--		write("011101", x"b196"); --29
--		write("011110", x"cba7"); --30
--		write("011111", x"475f"); --31
--		--MAC
--		write("100000", x"d624"); --32
--		write("100001", x"abe4"); --33
--		write("100010", x"dcfe"); --34
--		write("100011", x"31e4"); --35
--		
--		--Polling word
--		write("111111", (others => '0'));
--		while result = x"0000" loop
--			read("111111");
--		end loop;
--		
--		--MSG
--		read("011100"); --28
--		read("011101"); --29
--		read("011110"); --30
--		read("011111"); --31
--		--MAC
--		read("100000"); --32
--		read("100001"); --33
--		read("100010"); --34
--		read("100011"); --35
--		
--		write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");
--		result := (others=>'0');
-- 		wait for 60*HCLK_PERIOD;
--
--
--		
--		--Decrypt the second message
--		write("000000", "100011" & CONF_OPEN_TRANSACTION_POLMODE & "0000001"); 
--		
--	
--		--Length ct || CT = 0x08 
--		write("000001", x"0800");
--		--AD
--		--CT : 475f cba7 b196 81db 31e4 dcfe abe4 d624
--       write("000010", x"3122"); --2
--		write("000011", x"3f3a"); --3
--		write("000100", x"8b4a"); --4
--		write("000101", x"e195"); --5
--		--MAC
--		write("000110", x"5baa"); --6
--		write("000111", x"1a38"); --7
--		write("001000", x"2305"); --8
--		write("001001", x"4caa"); --9
--		
--		--Polling word
--		write("111111", (others => '0'));
--		while result = x"0000" loop
--			read("111111");
--		end loop;
--		
--		--MSG
--		read("000010"); --2
--		read("000011"); --3
--		read("000100"); --4
--		read("000101"); --5
--		--MAC
--		read("000110"); --6
--		read("000111"); --7
--		read("001000"); --8
--		read("001001"); --9
--		
--		write("000000", OPCODE_VOID & CONF_CLOSE_TRANSACTION_POLMODE & "0000001");		
--
--		result := (others=>'0');
--		wait for 60*HCLK_PERIOD;
------------------------------------------------------------------------------------------------------------
	wait;
	end process stimuli;
		
end Test;