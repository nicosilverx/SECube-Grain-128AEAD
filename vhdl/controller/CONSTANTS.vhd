--  ******************************************************************************
--  * File Name          : CONSTANTS.vhd
--  * Description        : Constants for the IP Manager architecture
--  ******************************************************************************
--  *
--  * Copyright � 2016-present Blu5 Group <https://www.blu5group.com>
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

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package CONSTANTS is
 	
 	-- SIZES AND NUMBERS
 	constant DATA_WIDTH	 : integer := 16;
	constant ADD_WIDTH	 : integer := 6;
	constant OPCODE_SIZE : integer := 6;
	constant MEM_SIZE	 : integer := 64;
	constant IPADDR_SIZE : integer := 7;
 	
	constant NUM_IPS : integer := 1;
		
	-- TYPES
	type data_array   is array (NUM_IPS-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
	type addr_array	  is array (NUM_IPS-1 downto 0) of std_logic_vector(ADD_WIDTH-1 downto 0);
	type opcode_array is array (NUM_IPS-1 downto 0) of std_logic_vector(OPCODE_SIZE-1 downto 0);
	
	-- CONTROL WORD FIELDS
	constant I_P_POS    : integer := 9;
	constant ACK_POS	: integer := 8;	
	constant B_E_POS    : integer := 7;
	constant IPADDR_POS : integer := 6; -- downto 0
	
end package CONSTANTS;
