----------------------------------------------------------------------------------
-- Created by: GIUSEPPE CARRUBBA / NICOLï¿½ BIANCO
-- Create Date: 12.09.2021
-- Module Name: grain_controller
-- Project Name: Lightweight cipher
-- Version: 1.1
-- Additional Comments: FSM-based controller to execute the encryp/decrypt APIs 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.CONSTANTS.all;

entity grain_controller is
	port(   
			clock                   : in std_logic;
			reset 				    : in std_logic;
			data_in 				: in std_logic_vector(DATA_WIDTH-1 downto 0);
			opcode 					: in std_logic_vector(OPCODE_SIZE-1 downto 0);
			enable 					: in std_logic;
			ack 					: in std_logic;
			interrupt_polling		: in std_logic;
			data_out 				: out std_logic_vector(DATA_WIDTH-1 downto 0);
			buffer_enable 			: out std_logic;
			address 				: out std_logic_vector(ADD_WIDTH-1 downto 0);
			rw 						: out std_logic;
			interrupt  				: out std_logic;
			error 					: out std_logic;
			write_completed			: in std_logic;
			read_completed			: in std_logic
		);
end grain_controller;

architecture Behavioral of grain_controller is

--Swap the significant bits in a single byte
function swapsb(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
variable return_vector : std_logic_vector(7 downto 0);
begin
    for k in 0 to 7 loop
        return_vector(k) := byte(7-k);
    end loop;
    return return_vector;
end swapsb;

type statetype is (OFF,
				   
				   WAIT_CW,
				   ADDR_CW,
				   READ_CW,
				   
				   DECODE_OPCODE,
				   
				   WAIT_KEY,
				   ADDR_KEY,
				   READ_KEY,
				   
				   WAIT_IV,
				   ADDR_IV,
				   READ_IV,

				   WAIT_LENGTH,
				   ADDR_LENGTH,
				   READ_LENGTH,

				   WAIT_AD,
				   ADDR_AD,
				   READ_AD,

				   WAIT_MSG,
				   ADDR_MSG,
				   READ_MSG,
				   
				   WAIT_MAC_DECRYPTION,
				   ADDR_MAC_DECRYPTION,
				   READ_MAC_DECRYPTION,
				   
				   INIT_CORE_IV,
				   OP_INIT_CORE_IV,
				   WAIT_CORE_IV,
				   
				   INIT_CORE_KEY,
				   OP_INIT_CORE_KEY,
				   WAIT_CORE_KEY,
				   
				   INIT_CORE_PRE_OUTPUT,
				   OP_INIT_CORE_PRE_OUTPUT,
				   WAIT_CORE_PRE_OUTPUT,
				   
				   INIT_CORE_ACC_NEXT_Z,
				   OP_INIT_CORE_ACC_NEXT_Z,
				   WAIT_LATCH_CORE_ACC_NEXT_Z,
				   WAIT_CORE_ACC_NEXT_Z,
				   
				   INIT_CORE_ACC_LOAD,
				   OP_INIT_CORE_ACC_LOAD,
				   WAIT_CORE_ACC_LOAD,
				   
				   INIT_CORE_SR_NEXT_Z,
				   OP_INIT_CORE_SR_NEXT_Z,
				   WAIT_LATCH_CORE_SR_NEXT_Z,
				   WAIT_CORE_SR_NEXT_Z,
				   
				   INIT_CORE_SR_LOAD,
				   OP_INIT_CORE_SR_LOAD,
				   WAIT_CORE_SR_LOAD,
				   
				   TAG_NEXT_Z,
				   OP_TAG_NEXT_Z,
				   WAIT_LATCH_TAG_NEXT_Z,
				   WAIT_TAG_NEXT_Z,
				   
				   TAG_ACCUMULATE,
				   OP_TAG_ACCUMULATE,
				   WAIT_TAG_ACCUMULATE,
				   
				   TAG_LOAD_SR,
				   OP_TAG_LOAD_SR,
				   WAIT_TAG_LOAD_SR,
				   
				   CIPHER_NEXT_Z,
				   OP_CIPHER_NEXT_Z,
				   WAIT_CIPHER_NEXT_Z,
				   WAIT_LATCH_CIPHER_NEXT_Z,
				   WAIT_LATCH_RAM_ENCRYPT,
				   
				   CIPHER_ACCUMULATE,
				   OP_CIPHER_ACCUMULATE,
				   WAIT_CIPHER_ACCUMULATE,
				   
				   
				   CIPHER_LOAD_SR,
				   OP_CIPHER_LOAD_SR,
				   WAIT_CIPHER_LOAD_SR,
				   
				   
				   CIPHER_NEXT_Z_1_DECRYPT,
				   OP_CIPHER_NEXT_Z_1_DECRYPT,
				   WAIT_LATCH_CIPHER_NEXT_Z_1_DECRYPT,
				   WAIT_CIPHER_NEXT_Z_1_DECRYPT,
				   WAIT_LATCH_RAM_DECRYPT,
				   
				   
				   CIPHER_NEXT_Z_2_DECRYPT,
				   OP_CIPHER_NEXT_Z_2_DECRYPT,
				   WAIT_LATCH_CIPHER_NEXT_Z_2_DECRYPT,
				   WAIT_CIPHER_NEXT_Z_2_DECRYPT,
				   
				   
				   CIPHER_ACCUMULATE_DECRYPT,
				   OP_CIPHER_ACCUMULATE_DECRYPT,
				   WAIT_CIPHER_ACCUMULATE_DECRYPT,
				   
				   
				   CIPHER_LOAD_SR_DECRYPT,
				   OP_CIPHER_LOAD_SR_DECRYPT,
				   WAIT_CIPHER_LOAD_SR_DECRYPT,
				   
				   GENERATE_USELESS_NEXT_Z,
				   OP_USELESS_NEXT_Z,
				   WAIT_USELESS_NEXT_Z,
				   
				   USELESS_ACCUMULATE,
				   OP_USELESS_ACCUMULATE,
				   WAIT_USELESS_ACCUMULATE,
				   
				   GET_MAC,
				   OP_GET_MAC,
				   WAIT_GET_MAC,
				   WAIT_LATCH_GET_MAC,
				   
				   COMPARE_MAC,
				   
				   UPDATE_STATE,
				   WAIT_ACK,
				   
				   LOAD_CT_RAM,
				   WAIT_LOAD_CT_RAM,
				   WRITE_MAC,
				   OP_WRITE_MAC,
				   WAIT_WRITE_MAC,

				   WRITE_CT,
				   OP_WRITE_CT,
				   WAIT_WRITE_CT,

           		   CLEAR_ALL,
                   DONE);

signal state: statetype; 

--GRAIN ROUND MODE
constant INIT   	: std_logic_vector(1 downto 0) := "00";
constant ADD_KEY    : std_logic_vector(1 downto 0) := "01";
constant NORMAL     : std_logic_vector(1 downto 0) := "10";

--OPERATION MODE
constant LOAD_IV		: std_logic_vector(2 downto 0) := "000";
constant LOAD_KEY		: std_logic_vector(2 downto 0) := "001";
constant NEXT_Z			: std_logic_vector(2 downto 0) := "010";
constant LOAD_AUTH_ACC	: std_logic_vector(2 downto 0) := "011";
constant LOAD_AUTH_SR	: std_logic_vector(2 downto 0) := "100";
constant ACCUMULATE		: std_logic_vector(2 downto 0) := "101";
constant READ_AUTH_ACC	: std_logic_vector(2 downto 0) := "110";

component grain128_core
    port(
            clk             : in std_logic;
            rst             : in std_logic;
            data_16_in      : in std_logic_vector(15 downto 0);
            data_16_addr_in : in std_logic_vector(2 downto 0);
            serial_data_in  : in std_logic;
            start           : in std_logic;
            operation       : in std_logic_vector(2 downto 0);
            grain_round     : in std_logic_vector(1 downto 0);
            data_16_out     : out std_logic_vector(15 downto 0);
            serial_data_out : out std_logic;
            completed       : out std_logic;
            busy            : out std_logic
        );
end component;

--RAM
component ram_16x16 is
    port (
        Clock: in  std_logic; 
        ClockEn: in  std_logic; 
        Reset: in  std_logic; 
        WE: in  std_logic; 
        Address: in  std_logic_vector(3 downto 0); 
        Data: in  std_logic_vector(15 downto 0); 
        Q: out  std_logic_vector(15 downto 0));
end component;

--SIGNALS FOR MSG_RAM
signal Address_s:   std_logic_vector(3 downto 0); 
signal Data_s:   std_logic_vector(15 downto 0); 
signal WE_s:   std_logic; 
signal Q_s:   std_logic_vector(15 downto 0);

--SIGNALS FOR CT_RAM
signal reset_ct  :  std_logic;
signal Address_ct:	std_logic_vector(3 downto 0);
signal Data_ct:		std_logic_vector(15 downto 0);
signal WE_ct: 		std_logic;
signal Q_ct:		std_logic_vector(15 downto 0);

signal serial_data_ct: std_logic_vector(15 downto 0);

--INTERCONNECTION WITH IP_CORE
signal data_16_in_c      :  std_logic_vector(15 downto 0);
signal data_16_addr_in_c :  std_logic_vector(2 downto 0);
signal serial_data_in_c  :  std_logic;
signal start_c           :  std_logic;
signal operation_c       :  std_logic_vector(2 downto 0);
signal grain_round_c     :  std_logic_vector(1 downto 0);
signal data_16_out_c     :  std_logic_vector(15 downto 0);
signal serial_data_out_c :  std_logic;
signal completed_c       :  std_logic;
signal busy_c            :  std_logic;
signal rst_c             :  std_logic;

signal set_init_core     :  std_logic;
signal NEXT_Z_reg		 :  std_logic;

--Memories
type memory_128 is array (7 downto 0) of std_logic_vector(15 downto 0);
type memory_64 is array (3 downto 0) of std_logic_vector(15 downto 0);
type memory_ad is array (9 downto 0) of std_logic_vector(7 downto 0);
type memory_msg is array (31 downto 0) of std_logic_vector(7 downto 0);
--REGS
signal CW      		 	: std_logic_vector(15  downto 0);

signal iv : memory_128;
signal key : memory_128;
signal AD : memory_ad;
--signal msg : memory_msg;
signal ct : memory_msg;



--signal IV 			  	: std_logic_vector(127 downto 0);
--signal key  			: std_logic_vector(127 downto 0);
signal lenght_submsg 	: std_logic_vector(7   downto 0);
signal lenght_AD     	: std_logic_vector(7   downto 0);
signal TAG 				: std_logic_vector(63 downto 0);
signal MAC_from_message: std_logic_vector(63 downto 0);
signal wc_count 		: std_logic_vector(7   downto 0);

begin

--RAM for MSG
ram_msg : ram_16x16 port map(clock, '1', reset, WE_s, Address_s, Data_s, Q_s);
ram_ct  : ram_16x16 port map(clock, '1', reset, WE_ct, Address_ct, Data_ct, Q_ct);
-- Cipher core instantiation
core: grain128_core port map (clock, rst_c, data_16_in_c, data_16_addr_in_c, serial_data_in_c, start_c,
                              operation_c, grain_round_c, data_16_out_c, serial_data_out_c,
	                          completed_c, busy_c);

------------------------------------------------------------------------

-- Syncr. process to count the write_completed signal's rising edge
process (clock, reset)
begin
    if(reset = '1') then
        wc_count <= std_logic_vector(to_unsigned(1, 8));
    elsif(rising_edge(clock)) then
        if(write_completed = '1') then
            wc_count <= std_logic_vector(to_unsigned(1, 8) + unsigned(wc_count));
        end if;
        if(enable = '0') then
            wc_count <= std_logic_vector(to_unsigned(1, 8));
        end if;
    end if;
end process;

-- FSM process
process (clock, reset)

variable key_count   		  : std_logic_vector(7 downto 0) := (others=>'0');	--Iterator for the key 
variable iv_count    		  : std_logic_vector(7 downto 0) := (others=>'0');	--Iterator for the iv
variable ad_count    		  : std_logic_vector(9 downto 0) := (others=>'0');	--Iterator for the AD
variable msg_count   	      : std_logic_vector(9 downto 0) := (others=>'0');	--Iterator for the MSG
variable msg_address_decode   : std_logic_vector(7 downto 0) := (others=>'0'); 	--Variable used to address message based on init packet or message packet.
variable lenght_adress_decode : std_logic_vector(7 downto 0) := (others=>'0');	--Variable used to address lenght of message on init packet or messagge packet.
variable pre_output_count     : std_logic_vector(8 downto 0) := (others=>'0'); 	--Iterator for the pre-output initial free-run
variable acc_count			  : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(127, 10)); 			--Iterator for the key when initial loading of ACC and SR
variable tag_count			  : std_logic_vector(9 downto 0) := (others=>'0');	--Iterator for the TAG accumulation
variable crypt_count		  : std_logic_vector(9 downto 0) := (others=>'0');	--Iterator for the encrypt/decrypt
variable ac_count			  : std_logic_vector(9 downto 0) := (others=>'0'); 	--Iterator 
variable mac_count			  : std_logic_vector(7 downto 0) := (others=>'0'); 	--Iterator for the MAC
variable wc_to_wait_length    : std_logic_vector(7 downto 0) := (others=>'0');	--# of write_completed before reading the lenght word
variable wc_to_wait_msg       : std_logic_vector(7 downto 0) := (others=>'0');	--# of write_completed before reading the msg words
variable encrypt_decrypt      : std_logic := '0';								--0 if encrypt, 1 if decrypt
variable next_z_addressing    : std_logic_vector(9 downto 0);
variable ct_ram_addressing	  : std_logic_vector(9 downto 0); 					--remove it if not used

variable debug : std_logic_vector(0 downto 0);
begin
	
	
	
	if(reset = '1') then
		--CORE SIGNALS
		set_init_core 		<= '0';
		rst_c				<= '1';
		data_16_in_c 		<= (others => '0');
		data_16_addr_in_c 	<= (others => '0');
		serial_data_in_c 	<= '0';
		start_c			    <= '0';
		operation_c 		<= (others => '0');
		grain_round_c 		<= (others => '0');

		--registers at 0
		CW 		      		<= (others => '0');
		IV	 	  	        <= (others => (others => '0'));
		KEY 		      	<= (others => (others => '0'));
		lenght_submsg 		<= (others => '0');
		lenght_AD     		<= (others => '0');
		AD 		      		<= (others => (others => '0')); 
		--MSG 		      	<= (others => (others => '0'));
		--CT 		      		<= (others => (others => '0'));
		TAG 		  		<= (others => '0');
		mac_from_message 	<= (others => '0');
		serial_data_ct      <= (others => '0');
		key_count 			:= (others => '0');
		iv_count 			:= (others => '0');
		ad_count 			:= (others => '0');
		msg_count 			:= (others => '0');
		msg_address_decode 	:= (others => '0');
		lenght_adress_decode:= (others => '0');
		pre_output_count 	:= (others => '0');
		acc_count 			:= std_logic_vector(to_unsigned(127, 10));
		tag_count 			:= (others => '0');
		crypt_count 		:= (others => '0');
		ac_count 			:= (others => '0');
		mac_count			:= (others => '0');
		wc_to_wait_length	:= (others => '0');
		wc_to_wait_msg		:= (others => '0');
		reset_ct 			<= '1';
		
		encrypt_decrypt		:= '0';
	elsif(rising_edge(clock)) then
		WE_s <= '0';
		WE_ct <= '0';
		case (state) is
----------------OFF STATE------------------------------------------------------------------------------
			when OFF =>
				--CORE SIGNALS
				rst_c <= '0';
				reset_ct <= '0';
				data_16_in_c <= (others => '0');
				data_16_addr_in_c <= (others => '0');
				serial_data_in_c <= '0';
				start_c <= '0';
				operation_c <= (others => '0');
				grain_round_c <= (others => '0');
				NEXT_Z_reg <= '0';
				----------------------------
				data_out <=  (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				------------------------------
				--registers at 0
				CW 		      		<= (others => '0');
				IV	 	  	        <= (others => (others => '0'));  IV(1) <= x"FFFF"; IV(0) <= x"FFFE";
				KEY 		      	<= (others => (others => '0'));
				lenght_submsg 		<= (others => '0');
				lenght_AD     		<= (others => '0');
				AD 		      		<= (others => (others => '0'));
				TAG 		  		<= (others => '0');
				mac_from_message 	<= (others => '0');
				serial_data_ct      <= (others => '0');
				key_count 			:= (others => '0');
				iv_count 			:= (others => '0');
				ad_count 			:= (others => '0');
				msg_count 			:= (others => '0');
				msg_address_decode 	:= (others => '0');
				lenght_adress_decode:= (others => '0');
				pre_output_count 	:= (others => '0');
				acc_count 			:= std_logic_vector(to_unsigned(127, 10));
				tag_count 			:= (others => '0');
				crypt_count 		:= (others => '0');
				ac_count 			:= (others => '0');
				mac_count			:= (others => '0');
				wc_to_wait_length	:= (others => '0');
				wc_to_wait_msg		:= (others => '0');
				
                ----------------------------------
			    if(enable = '1') then
			    	state <= WAIT_CW;
			    else
			    	state <= OFF;
			    end if;
-------------------READ CW---------------------------------------------------------------------------
			when WAIT_CW =>
				  if(to_integer(unsigned(wc_count)) = 1 OR write_completed = '1') then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(0, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_CW;
				else
					state <= WAIT_CW;
			    end if;

			WHEN ADDR_CW =>
				state <= READ_CW;

			WHEN READ_CW =>
				CW <= data_in;
				data_out <= (others => '0');
				buffer_enable <= '0
				';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				state <= DECODE_OPCODE;
---------------------EVALUATE PACKET TYPE------------------------------------------------------------------------
			WHEN DECODE_OPCODE =>
				case CW(15 downto 10) is
					when "100000" => --init encrypt
						state <= WAIT_KEY;
						msg_address_decode := std_logic_vector(to_unsigned(28, 8));
						lenght_adress_decode := std_logic_vector(to_unsigned(17, 8));
						
						wc_to_wait_length := std_logic_vector(to_unsigned(16, 8));

						encrypt_decrypt := '0';			--Encrypt
						set_init_core <= '1';			--Init
						rst_c <= '1';					--Clear the cipher
					when "100001" => --encrypt message
						state <= WAIT_LENGTH;
						msg_address_decode := std_logic_vector(to_unsigned(2, 8));
						lenght_adress_decode := std_logic_vector(to_unsigned(1, 8));
						
						wc_to_wait_length := std_logic_vector(to_unsigned(2, 8));
						wc_to_wait_msg    := std_logic_vector(to_unsigned(2, 8));

						encrypt_decrypt := '0';			--Encrypt
						set_init_core <= '0';			--No init
						rst_c <= '0';					
					when "100010" => --init decrypt
						state <= WAIT_KEY;
						msg_address_decode := std_logic_vector(to_unsigned(28, 8));
						lenght_adress_decode := std_logic_vector(to_unsigned(17, 8));
						
						wc_to_wait_length := std_logic_vector(to_unsigned(16, 8));

						encrypt_decrypt := '1';			--Decrypt
						set_init_core <= '1';			--Init
						rst_c <= '1';					--Clear the cipher
					when "100011" => --decrypt message
					    state <= WAIT_LENGTH;
					    msg_address_decode := std_logic_vector(to_unsigned(2, 8));
						lenght_adress_decode := std_logic_vector(to_unsigned(1, 8));
						
						wc_to_wait_length := std_logic_vector(to_unsigned(2, 8));
						wc_to_wait_msg    := std_logic_vector(to_unsigned(2, 8));

						encrypt_decrypt := '1';			--Decrypt
						set_init_core <= '0';			--Not init
						rst_c <= '0';
					when OTHERS =>
						state <= OFF;
				end case;
--------------------READING KEY-------------------------------------------------------------------------
		    when WAIT_KEY =>
		    	if(to_integer(unsigned(wc_count)) >(1+to_integer(unsigned(key_count)))) then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(key_count))+1, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_KEY;
				else
					state <= WAIT_KEY;
				end if;

		    when ADDR_KEY =>
		    	state <= READ_KEY;

		    WHEN READ_KEY =>
		    	--key((15+(16*key_count)) downto (16*key_count)) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
				key(to_integer(unsigned(key_count))) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(to_integer(unsigned(key_count)) < 7) then
					key_count := std_logic_vector(to_unsigned(1, 8) + unsigned(key_count));

					state <= WAIT_KEY;
			    else
					key_count := std_logic_vector(to_unsigned(0, 8));
			    	state <= WAIT_IV;
			    	rst_c <= '0';
			    end if;
-------------------READING INITIALIZTION VECTOR-----------------------------------------------------------------------
		    WHEN WAIT_IV =>
		    	if(to_integer(unsigned(wc_count))>(1+8+to_integer(unsigned(IV_count)))) then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(IV_count))+1+8, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_IV;
				else
					state <= WAIT_IV;
				end if;

			WHEN ADDR_IV =>
				state <= READ_IV;

			WHEN READ_IV =>
				--IV((15+(16*(iv_count+2))) downto (16*(iv_count+2))) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
				iv(to_integer(unsigned(iv_count)) + 2) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(to_integer(unsigned(iv_count)) < 5) then
					iv_count := std_logic_vector(to_unsigned(1, 8) + unsigned(iv_count));
					state <= WAIT_IV;
			    else
			    	iv_count := std_logic_vector(to_unsigned(0, 8));
			    	state <= WAIT_LENGTH;
			    end if;
--------------READING LENGHT OF ASSOCIATED DATA AND MESSAGE----------------------------------------------------------------
		    WHEN WAIT_LENGTH =>
		    	if(to_integer(unsigned(wc_count)) > to_integer(unsigned(wc_to_wait_length))) then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(lenght_adress_decode)), ADD_WIDTH)); 
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_LENGTH;
				else
					state <= WAIT_LENGTH;
			    end if;

			WHEN ADDR_LENGTH =>
				state <= READ_LENGTH;

			WHEN READ_LENGTH =>
				lenght_submsg <= data_in(15 downto 8);
				lenght_AD <= data_in(7 downto 0);  
				data_out <= (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(set_init_core = '1') then
					state <= WAIT_AD;
				else
					state <= WAIT_MSG;
				end if;
-------------------------READING ASSOCIATED DATA---------------------------------------------------------------
			WHEN WAIT_AD =>
                if(to_integer(unsigned(wc_count)) > to_integer(unsigned(wc_to_wait_length)) + to_integer(unsigned(AD_count))/2) then 
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(AD_count))/2 + 18, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_AD;
				else
					state <= WAIT_AD;
				end if;

			WHEN ADDR_AD =>
				state <= READ_AD;

			WHEN READ_AD =>
				--AD((15+(16*AD_count)) downto (16*AD_count)) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));	
				AD(to_integer(unsigned(AD_count))) <= swapsb(data_in(15 downto 8));
				AD(to_integer(unsigned(AD_count))+1) <= swapsb(data_in(7 downto 0));
				
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(to_integer(unsigned(AD_count)) < (to_integer(unsigned(lenght_AD)))-1) then
					ad_count := std_logic_vector(to_unsigned(2, 10) + unsigned(ad_count));
					state <= WAIT_AD;
			    else
			    	ad_count := std_logic_vector(to_unsigned(0, 10));
			    	state <= WAIT_MSG;
			    	-- AD_length || AD
			    	--AD(7+(8*to_integer(unsigned(lenght_AD))) downto (8*to_integer(unsigned(lenght_AD)))) <= swapsb(lenght_AD);
			    	AD(to_integer(unsigned(lenght_AD))) <= swapsb(lenght_AD);

			    	if(set_init_core = '1') then
					   --wc_to_wait_msg := 1+8+6+1+(to_integer(unsigned(lenght_AD))/2) ;
					   wc_to_wait_msg := std_logic_vector(to_unsigned(16, 8) + unsigned(lenght_AD)/2);
					else
					wc_to_wait_msg := std_logic_vector(to_unsigned(2, 8));
					end if;
			    end if;
------------------READING MESSAGE------------------------------------------------------------			 
			 WHEN WAIT_MSG =>
                if(to_integer(unsigned(wc_count)) > to_integer(unsigned(wc_to_wait_msg)) + to_integer(unsigned(MSG_count))/2) then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(MSG_count)/2) + to_integer(unsigned(msg_address_decode)), ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_MSG;
				else
					state <= WAIT_MSG;
				end if;

			WHEN ADDR_MSG =>
				state <= READ_MSG;

			WHEN READ_MSG =>
				
				Address_s <= MSG_count(4 downto 1);
				Data_s <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
				WE_s <= '1';
				
				--MSG(to_integer(unsigned(MSG_count))+1) <= swapsb(data_in(15 downto 8));
				--MSG(to_integer(unsigned(MSG_count))) <= swapsb(data_in(7 downto 0));
				
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(to_integer(unsigned(MSG_count)) < (to_integer(unsigned(lenght_submsg)))-1) then
					MSG_count := std_logic_vector(to_unsigned(2, 10) + unsigned(MSG_count));
					state <= WAIT_MSG;
			    else
				    MSG_count := std_logic_vector(to_unsigned(0, 10));
			    	if(set_init_core = '1') then
			    	    if(encrypt_decrypt = '0') then
			    	        state <= INIT_CORE_IV;
			    	    else
			    	        state <= WAIT_MAC_DECRYPTION;
			    	    end if;
			    	else
			    	    if(encrypt_decrypt = '0') then
			    	        state <= CIPHER_NEXT_Z;
			    	    else
			    	        state <= WAIT_MAC_DECRYPTION;
			    	    end if;
			    	end if;
			    end if;
			    
----------------READ FROM MSG FOR DECRYPTION----------------------
            WHEN WAIT_MAC_DECRYPTION =>
                if(to_integer(unsigned(wc_count))> (to_integer(unsigned(wc_to_wait_msg)) + to_integer(unsigned(MSG_count))/2 + 4)) then
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(MSG_count)) + to_integer(unsigned(msg_address_decode)) + 4, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_MAC_DECRYPTION;
				else
					state <= WAIT_MAC_DECRYPTION;
				end if;

			WHEN ADDR_MAC_DECRYPTION =>
				state <= READ_MAC_DECRYPTION;

			WHEN READ_MAC_DECRYPTION =>
				--MSG((15+(16*(MSG_count+4))) downto (16*(MSG_count+4))) <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
				--msg(to_integer(unsigned(MSG_COUNT)) + 8+ 1) <= swapsb(data_in(15 downto 8));
				--msg(to_integer(unsigned(MSG_COUNT)) + 8 ) <= swapsb(data_in(7 downto 0));
				
				Address_s <= std_logic_vector(unsigned(MSG_count(4 downto 1)) + 4);
				Data_s <= swapsb(data_in(15 downto 8)) & swapsb(data_in(7 downto 0));
				WE_s <= '1';
				
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(to_integer(unsigned(MSG_count)) < 8) then
					MSG_count := std_logic_vector(to_unsigned(2, 10) + unsigned(MSG_count));
					state <= WAIT_MAC_DECRYPTION;
			    else
					MSG_count := std_logic_vector(to_unsigned(0, 10));
			    	if(set_init_core = '1') then
			    		state <= INIT_CORE_IV;
			    	else
			    		state <= CIPHER_NEXT_Z_1_DECRYPT;
			    	end if;
			    end if;
			    
----------------INITIALIZATION VECTOR CORE---------------------------------------------------
			WHEN INIT_CORE_IV =>
				if(completed_c = '1') then
					if(to_integer(unsigned(iv_count)) <= 7) then
						start_c <= '1';
						operation_c <= LOAD_IV;
						data_16_in_c <= IV(to_integer(unsigned(iv_count)));
						data_16_addr_in_c <= std_logic_vector(to_unsigned(to_integer(unsigned(IV_count)), 3));
						state <= OP_INIT_CORE_IV;
					else
						iv_count := std_logic_vector(to_unsigned(0, 8));
						state <= INIT_CORE_KEY;
					end if;
				else
					state <= INIT_CORE_IV;
				end if;
            
            WHEN OP_INIT_CORE_IV =>
                state <= WAIT_CORE_IV;
            
			WHEN WAIT_CORE_IV =>
			    start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_IV;
				else
					iv_count := std_logic_vector(to_unsigned(1, 8) + unsigned(iv_count));
					state <= INIT_CORE_IV;
				end if;
-------------------INIT READING KEY CORE-------------------------------------------------------
			WHEN INIT_CORE_KEY =>
				if(completed_c = '1') then
					if(to_integer(unsigned(key_count)) <= 7) then
						start_c <= '1';
						operation_c <= LOAD_KEY;
						data_16_in_c <= KEY(to_integer(unsigned(key_count)));
						data_16_addr_in_c <= std_logic_vector(to_unsigned(to_integer(unsigned(key_count)), 3));
						state <= OP_INIT_CORE_KEY;
					else
						key_count := std_logic_vector(to_unsigned(0, 8));
						state <= INIT_CORE_PRE_OUTPUT;
					end if;
				else
					state <= INIT_CORE_KEY;
				end if;
            
            WHEN OP_INIT_CORE_KEY =>
                state <= WAIT_CORE_KEY;
            
			WHEN WAIT_CORE_KEY =>
			    start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_KEY;
				else
					key_count := std_logic_vector(to_unsigned(1, 8) + unsigned(key_count));
					state <= INIT_CORE_KEY;
				end if;
-----------------RUN FOR PREPARE OUTPUT---------------------------------------------------
		    WHEN INIT_CORE_PRE_OUTPUT =>
		    	IF(completed_c = '1') then
		    		if(to_integer(unsigned(pre_output_count)) <= 255) then
		    			operation_c <= NEXT_Z;
		    			grain_round_c <= INIT;
		    			start_c <= '1';
		    			--core signals setup
		    			data_16_in_c <= (others => '0');
		    			data_16_addr_in_c <= (others => '0');
		    			serial_data_in_c <= '0';
		    			-------------------------------------
		    			state <= OP_INIT_CORE_PRE_OUTPUT;
		    		else
		    			pre_output_count := std_logic_vector(to_unsigned(0, 9));
		    			state <= INIT_CORE_ACC_NEXT_Z;
		    		end if;
		    	else
		    		state <= INIT_CORE_PRE_OUTPUT;
		    	end if;
            
            WHEN OP_INIT_CORE_PRE_OUTPUT =>
                state <= WAIT_CORE_PRE_OUTPUT;
                
		    WHEN WAIT_CORE_PRE_OUTPUT =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_PRE_OUTPUT;
				else
				    pre_output_count := std_logic_vector(to_unsigned(1, 9) + unsigned(pre_output_count));
					state <= INIT_CORE_PRE_OUTPUT;
				end if;
---------------------LOADING ACCUMULATOR-------------------------------------------------------
			WHEN INIT_CORE_ACC_NEXT_Z =>
				if(completed_c = '1') then
					if(to_integer(unsigned(acc_count)) > 63) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						serial_data_in_c <= KEY(to_integer(unsigned(acc_count))/16)(to_integer(unsigned(acc_count)) mod 16);
						state <= OP_INIT_CORE_ACC_NEXT_Z;
					else
						acc_count := std_logic_vector(to_unsigned(63, 10));
						state <= INIT_CORE_SR_NEXT_Z;
					end if;
				else
					state <= INIT_CORE_ACC_NEXT_Z;
                end if;
            
            WHEN OP_INIT_CORE_ACC_NEXT_Z =>
                state <= WAIT_CORE_ACC_NEXT_Z;

			WHEN WAIT_CORE_ACC_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_ACC_NEXT_Z;
				else
					state <= WAIT_LATCH_CORE_ACC_NEXT_Z;
				end if;
            
            WHEN WAIT_LATCH_CORE_ACC_NEXT_Z =>
                if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    state <= INIT_CORE_ACC_LOAD;
                else
                    state <= WAIT_LATCH_CORE_ACC_NEXT_Z;
                end if;
                
			WHEN INIT_CORE_ACC_LOAD =>
				if(completed_c = '1') then
					start_c <= '1';
					operation_c <= LOAD_AUTH_ACC;
					grain_round_c <= ADD_KEY;
					serial_data_in_c <= NEXT_Z_reg;
					state <= OP_INIT_CORE_ACC_LOAD;
				else
					state <= INIT_CORE_ACC_LOAD;
				end if;
            
            WHEN OP_INIT_CORE_ACC_LOAD =>
                state <= WAIT_CORE_ACC_LOAD;
                
			WHEN WAIT_CORE_ACC_LOAD =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_ACC_LOAD;
				else
					acc_count := std_logic_vector(unsigned(acc_count) - to_unsigned(1, 10));
					state <= INIT_CORE_ACC_NEXT_Z;
				end if;
------------------LOADING SHIFT REGISTER-----------------------------------------------------
			WHEN INIT_CORE_SR_NEXT_Z =>
				if(completed_c = '1') then
					if(to_integer(unsigned(acc_count)) >= 0 AND to_integer(unsigned(acc_count))<128) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						--report "acc_count: " & integer'image(to_integer(unsigned(acc_count))) & " key[" & integer'image(to_integer(unsigned(acc_count))/16)& "][" & integer'image(to_integer(unsigned(acc_count)) mod 16) & "]";
						serial_data_in_c <= KEY(to_integer(unsigned(acc_count))/16)(to_integer(unsigned(acc_count)) mod 16);
						state <= OP_INIT_CORE_SR_NEXT_Z;
					else
						acc_count := std_logic_vector(to_unsigned(0, 10));
						state <= TAG_NEXT_Z;
					end if;
				else
					state <= INIT_CORE_SR_NEXT_Z;
				end if;
            
            WHEN OP_INIT_CORE_SR_NEXT_Z =>
                state <= WAIT_CORE_SR_NEXT_Z;
            
			WHEN WAIT_CORE_SR_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_SR_NEXT_Z;
				else
					state <= WAIT_LATCH_CORE_SR_NEXT_Z;
				end if;
            
            WHEN WAIT_LATCH_CORE_SR_NEXT_Z =>
                if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    state <= INIT_CORE_SR_LOAD;
                else
                    state <= WAIT_LATCH_CORE_SR_NEXT_Z;
                end if;
                
			WHEN INIT_CORE_SR_LOAD =>
				if(completed_c = '1') then
					start_c <= '1';
					operation_c <= LOAD_AUTH_SR;
					grain_round_c <= ADD_KEY;
					serial_data_in_c <= NEXT_Z_reg;
					state <= OP_INIT_CORE_SR_LOAD;
				else
					state <= INIT_CORE_SR_LOAD;
				end if;
              
            WHEN OP_INIT_CORE_SR_LOAD =>
                state <= WAIT_CORE_SR_LOAD;   
              
			WHEN WAIT_CORE_SR_LOAD =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CORE_SR_LOAD;
				else
					acc_count := std_logic_vector(unsigned(acc_count) - to_unsigned(1, 10));
					state <= INIT_CORE_SR_NEXT_Z;
				end if;
---------------ACCUMULATE TAG--------------------------------------------------------------------
			WHEN TAG_NEXT_Z =>
				if(completed_c = '1') then
					if(to_integer(unsigned(tag_count)) < (to_integer(unsigned(lenght_AD) + 1)*2*8)) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_TAG_NEXT_Z;
					else
						tag_count := std_logic_vector(to_unsigned(0, 10));
						ad_count  := std_logic_vector(to_unsigned(0, 10));
						if(encrypt_decrypt = '0') then
						  state <= CIPHER_NEXT_Z;
						else
						  state <= CIPHER_NEXT_Z_1_DECRYPT;
					    end if;
					end if;
				else
					state <= TAG_NEXT_Z;
				end if;
            
            WHEN OP_TAG_NEXT_Z =>
                state <= WAIT_TAG_NEXT_Z;
            
			WHEN WAIT_TAG_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_TAG_NEXT_Z;
				else
					state <= WAIT_LATCH_TAG_NEXT_Z;
				end if;
            
            WHEN WAIT_LATCH_TAG_NEXT_Z =>
                if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    state <= TAG_ACCUMULATE;
                else
                    state <= WAIT_LATCH_TAG_NEXT_Z;
                end if;
            
			WHEN TAG_ACCUMULATE =>
				if(completed_c = '1') then
					if( ( (to_integer(unsigned(tag_count)))mod 2) = 0 ) then
					       state <= WAIT_TAG_LOAD_SR;
				    else
						if(AD  ( ( to_integer(unsigned(lenght_AD)) - to_Integer(unsigned(AD_count))/8))  ( 7 - to_integer(unsigned(AD_count)) mod 8)  = '1') then
						
                            start_c <= '1';
                            operation_c <= ACCUMULATE;
                            state <= OP_TAG_ACCUMULATE;
                        else
                            start_c <= '0';
                            state <= TAG_LOAD_SR;
                        end if;
                        ad_count := std_logic_vector(unsigned(ad_count) + to_unsigned(1, 10));
					end if;
				else
					state <= TAG_ACCUMULATE;
				end if;
            
            WHEN OP_TAG_ACCUMULATE =>
                state <= WAIT_TAG_ACCUMULATE;
            
			WHEN WAIT_TAG_ACCUMULATE =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_TAG_ACCUMULATE;
				else
					state <= TAG_LOAD_SR;
				end if;
			
			WHEN TAG_LOAD_SR =>
			     if(completed_c = '1') then
			         start_c <= '1';
			         operation_c <= LOAD_AUTH_SR;
			         serial_data_in_c <= NEXT_Z_reg;
			         state <= OP_TAG_LOAD_SR;
			     else 
			         state <= TAG_LOAD_SR;
			     end if;
			
			WHEN OP_TAG_LOAD_SR =>
			     state <= WAIT_TAG_LOAD_SR;
			    
			WHEN WAIT_TAG_LOAD_SR =>
			     start_c <= '0';
			     if(busy_c = '1')then
			         state <= WAIT_TAG_LOAD_SR;
			     else
			         tag_count := std_logic_vector(unsigned(tag_count) + to_unsigned(1, 10));
			         state <= TAG_NEXT_Z;
			     end if;
			
--------------ENCRYPTION-----------------------------------------------
			WHEN CIPHER_NEXT_Z =>
				if(completed_c = '1') then
					if(to_integer(unsigned(crypt_count)) < to_integer(unsigned(lenght_submsg))*2*8 ) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_CIPHER_NEXT_Z;
					else
						crypt_count := std_logic_vector(to_unsigned(0, 10));
						msg_count := std_logic_vector(to_unsigned(0, 10));
						ac_count := std_logic_vector(to_unsigned(0, 10));
						state <= GENERATE_USELESS_NEXT_Z;
					end if;
				else
					state <= CIPHER_NEXT_Z;
				end if;
            
            WHEN OP_CIPHER_NEXT_Z =>
                state <= WAIT_CIPHER_NEXT_Z;
            
			WHEN WAIT_CIPHER_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CIPHER_NEXT_Z;
				else
					state <= WAIT_LATCH_CIPHER_NEXT_Z;
				end if;
				
			WHEN WAIT_LATCH_CIPHER_NEXT_Z =>
                if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    state <= WAIT_LATCH_RAM_ENCRYPT;
					
					next_z_addressing := std_logic_vector("00"&(unsigned(lenght_submsg)/2) - 1 - unsigned(MSG_count(7 downto 4)));
					Address_s <= next_z_addressing(3 downto 0);
					
					
                else
                    state <= WAIT_LATCH_CIPHER_NEXT_Z;
                end if;
				
			WHEN WAIT_LATCH_RAM_ENCRYPT =>
				state <= CIPHER_ACCUMULATE;
			

			WHEN CIPHER_ACCUMULATE =>
				if(completed_c = '1') then
					if((to_integer(Unsigned(crypt_count)) mod 2) = 0) then
						serial_data_ct((15 - to_integer(unsigned(ac_count))mod 16)) <= Q_s(15 -to_integer(unsigned(msg_count))mod 16) xor NEXT_Z_reg;
						--CT(((to_integer(unsigned(lenght_submsg))) - 1 - to_integer(unsigned(msg_count))/8 ))(7 - to_integer(unsigned(msg_count))mod 8) <= Q_s(15 -to_integer(unsigned(msg_count))mod 16) xor NEXT_Z_reg;
						--debug(0) := Q_s(15 -to_integer(unsigned(msg_count))mod 16);
						--report "msg: " & integer'image(to_integer(unsigned(debug)));
						--report "Q_s: " & to_hstring(q_s) & " @: " & to_hstring(next_z_addressing); 
						msg_count := std_logic_vector(unsigned(msg_count) + to_unsigned(1, 10));
						state <= WAIT_CIPHER_LOAD_SR;
					else
						if(Q_s(15 -to_integer(unsigned(ac_count))mod 16) = '1') then 
							operation_c <= ACCUMULATE;
							start_c <= '1';
							state <= OP_CIPHER_ACCUMULATE;
						else
						    state <= CIPHER_LOAD_SR; 
						end if;
						ac_count := std_logic_vector(unsigned(ac_count) + to_unsigned(1, 10));

						if( (to_integer(unsigned(ac_count)) mod 16) = 0 and (to_integer(unsigned(ac_count)))  > 0) then
								WE_ct <= '1';
								ct_ram_addressing := std_logic_vector("00"&(unsigned(lenght_submsg)/2) - 1 - unsigned(MSG_count(7 downto 4)));
								address_ct <= ct_ram_addressing(3 downto 0);
								data_ct <= serial_data_ct;
						end if;

					end if;
				else
					state <= CIPHER_ACCUMULATE;
				end if;
            
            WHEN OP_CIPHER_ACCUMULATE =>
                state <= WAIT_CIPHER_ACCUMULATE;
                 
			WHEN WAIT_CIPHER_ACCUMULATE =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CIPHER_ACCUMULATE;
				else
					state <= CIPHER_LOAD_SR;
				end if;

			WHEN CIPHER_LOAD_SR =>
				if(completed_c = '1') then
					operation_c <= LOAD_AUTH_SR;
					serial_data_in_c <= NEXT_Z_reg;
					start_c <= '1';
					state  <= OP_CIPHER_LOAD_SR;
				else
					state <= CIPHER_LOAD_SR;
				end if;
            
            WHEN OP_CIPHER_LOAD_SR =>
                state <= WAIT_CIPHER_LOAD_SR;
            
			WHEN WAIT_CIPHER_LOAD_SR =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CIPHER_LOAD_SR;
				else
					crypt_count := std_logic_vector(unsigned(crypt_count) + to_unsigned(1, 10));
					state <= CIPHER_NEXT_Z;
				end if;
				
--------------DECRYPTION-----------------------------------------------
			WHEN CIPHER_NEXT_Z_1_DECRYPT=>
			     if(completed_c = '1') then
					if(to_integer(unsigned(crypt_count)) < to_integer(unsigned(lenght_submsg))*8 ) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_CIPHER_NEXT_Z_1_DECRYPT;
					else
						crypt_count := std_logic_vector(to_unsigned(0, 10));
						ac_count := std_logic_vector(to_unsigned(0, 10));
						msg_count := std_logic_vector(to_unsigned(0, 10));
						state <= GENERATE_USELESS_NEXT_Z;
					end if;
				else
					state <= CIPHER_NEXT_Z_1_DECRYPT;
				end if;
				
			WHEN OP_CIPHER_NEXT_Z_1_DECRYPT =>
			     state <= WAIT_CIPHER_NEXT_Z_1_DECRYPT;
			
			WHEN WAIT_CIPHER_NEXT_Z_1_DECRYPT =>
                start_c <= '0';
                if(busy_c = '1') then
                    state <= WAIT_CIPHER_NEXT_Z_1_DECRYPT;
                else
                    state <= WAIT_LATCH_CIPHER_NEXT_Z_1_DECRYPT;
                end if;
                
			WHEN WAIT_LATCH_CIPHER_NEXT_Z_1_DECRYPT =>
			     if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    state <= WAIT_LATCH_RAM_DECRYPT;
                 else
                    state <= WAIT_LATCH_CIPHER_NEXT_Z_1_DECRYPT;
					
					 next_z_addressing := std_logic_vector("00"&(unsigned(lenght_submsg)/2) - 1 - unsigned(ac_count(7 downto 4)));
					 Address_s <= next_z_addressing(3 downto 0);
						
					 --Address_s <= std_logic_vector(unsigned(lenght_submsg) - 1 - unsigned(ac_count(7 downto 4)));
					 
                 end if; 
			
			WHEN WAIT_LATCH_RAM_DECRYPT =>
				state <= CIPHER_NEXT_Z_2_DECRYPT;
			
			WHEN CIPHER_NEXT_Z_2_DECRYPT =>
			     if(completed_c = '1') then
			            --CT(to_integer(unsigned(lenght_submsg))*8 - 1 - ac_count) <= MSG(to_integer(unsigned(lenght_submsg))*8 - 1 - ac_count) xor NEXT_Z_reg;
						--CT(((to_integer(unsigned(lenght_submsg))) - 1 - to_integer(unsigned(ac_count))/8 ))(7 - to_integer(unsigned(ac_count))mod 8) <= Q_s(15 -to_integer(unsigned(ac_count))mod 16) xor NEXT_Z_reg;
						serial_data_ct((15 - to_integer(unsigned(ac_count))mod 16)) <= Q_s(15 -to_integer(unsigned(msg_count))mod 16) xor NEXT_Z_reg;
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_CIPHER_NEXT_Z_2_DECRYPT;
				 else
					state <= CIPHER_NEXT_Z_2_DECRYPT;
				 end if;
			
			WHEN OP_CIPHER_NEXT_Z_2_DECRYPT =>
			     state <= WAIT_CIPHER_NEXT_Z_2_DECRYPT;
			     
			WHEN WAIT_CIPHER_NEXT_Z_2_DECRYPT =>
			      start_c <= '0';
                  if(busy_c = '1') then
                    state <= WAIT_CIPHER_NEXT_Z_2_DECRYPT;
                  else
                    state <= WAIT_LATCH_CIPHER_NEXT_Z_2_DECRYPT;
                  end if;
                  
			WHEN WAIT_LATCH_CIPHER_NEXT_Z_2_DECRYPT =>
			      if(completed_c = '1') then
                    NEXT_Z_reg <= serial_data_out_c;
                    if(serial_data_ct((15 - to_integer(unsigned(ac_count))mod 16)) = '1') then
					--if(CT(((to_integer(unsigned(lenght_submsg))) - 1 - to_integer(unsigned(ac_count))/8 ))(7 - to_integer(unsigned(ac_count))mod 8) = '1') then
                        operation_c <= ACCUMULATE;
                        start_c <= '1';
                        state <= OP_CIPHER_ACCUMULATE_DECRYPT;
                    else
                        state <= CIPHER_LOAD_SR_DECRYPT;
                    end if;
                  else
                    state <= WAIT_LATCH_CIPHER_NEXT_Z_2_DECRYPT;
                  end if;
			
			
			--WHEN CIPHER_ACCUMULATE_DECRYPT =>
			WHEN OP_CIPHER_ACCUMULATE_DECRYPT =>
			     state <= WAIT_CIPHER_ACCUMULATE_DECRYPT;
			     
			WHEN WAIT_CIPHER_ACCUMULATE_DECRYPT =>
			     start_c <= '0';
				  if(busy_c = '1') then
					state <= WAIT_CIPHER_ACCUMULATE_DECRYPT;
				  else
					state <= CIPHER_LOAD_SR_DECRYPT;
				  end if;
				  
			WHEN CIPHER_LOAD_SR_DECRYPT =>
			     if(completed_c = '1') then
					operation_c <= LOAD_AUTH_SR;
					serial_data_in_c <= NEXT_Z_reg;
					start_c <= '1';
					state  <= OP_CIPHER_LOAD_SR_DECRYPT;
				  else
					state <= CIPHER_LOAD_SR_DECRYPT;
				  end if;
			
			WHEN OP_CIPHER_LOAD_SR_DECRYPT =>
			     state <= WAIT_CIPHER_LOAD_SR_DECRYPT;
			     
			WHEN WAIT_CIPHER_LOAD_SR_DECRYPT=>
			     start_c <= '0';
				  if(busy_c = '1') then
					state <= WAIT_CIPHER_LOAD_SR_DECRYPT;
				  else
				 	crypt_count := std_logic_vector(unsigned(crypt_count) + to_unsigned(1, 10));
					ac_count := std_logic_vector(unsigned(ac_count) + to_unsigned(1, 10));
					if( (to_integer(unsigned(ac_count)) mod 16) = 0 and (to_integer(unsigned(ac_count)))  > 0) then
								WE_ct <= '1';
								ct_ram_addressing := std_logic_vector("00"&(unsigned(lenght_submsg)/2) - 1 - unsigned(MSG_count(7 downto 4)));
								address_ct <= ct_ram_addressing(3 downto 0);
								data_ct <= serial_data_ct;
					end if;

					state <= CIPHER_NEXT_Z_1_DECRYPT;
				  end if;
			
---------------------PREPARE OUTPUT-----------------------------------------------
			WHEN GENERATE_USELESS_NEXT_Z =>
				if(completed_c = '1') then
					operation_c <= NEXT_Z;
					grain_round_c <= NORMAL;
					serial_data_in_c <= '0';
					start_c <= '1';
					state <= OP_USELESS_NEXT_Z;
				else
					state <= GENERATE_USELESS_NEXT_Z;
				end if;
            
            WHEN OP_USELESS_NEXT_Z =>
                state <= WAIT_USELESS_NEXT_Z;
                
			WHEN WAIT_USELESS_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_USELESS_NEXT_Z;
				else
					state <= USELESS_ACCUMULATE;
				end if;

			WHEN USELESS_ACCUMULATE =>
				if(completed_c = '1') then
					start_c <= '1';
					operation_c <= ACCUMULATE;
					state <= OP_USELESS_ACCUMULATE;
				else 
					state <= USELESS_ACCUMULATE;
				end if;
            
            WHEN OP_USELESS_ACCUMULATE =>
                state <= WAIT_USELESS_ACCUMULATE;
                
			WHEN WAIT_USELESS_ACCUMULATE =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_USELESS_ACCUMULATE;
				else
					
					state <= GET_MAC;
				end if;
----------------------GET THE MAC FROM THE CIPHER--------------------------------------------------------
			WHEN GET_MAC =>
				if(completed_c = '1') then
					if(to_integer(unsigned(mac_count)) < 4) then
						operation_c <= READ_AUTH_ACC;
						data_16_addr_in_c <= std_logic_vector(to_unsigned(to_integer(unsigned(mac_count)), 3));
						start_c <= '1';
						state <= OP_GET_MAC;
						Address_s <= std_logic_vector(to_unsigned(to_integer((unsigned(lenght_submsg))/2) + to_integer(unsigned(mac_count)), 4));
						report "address " & to_hstring(std_logic_vector(to_unsigned(to_integer((unsigned(lenght_submsg))/2) + to_integer(unsigned(mac_count)), 4)));
					else    
						mac_count := std_logic_vector(to_unsigned(0, 8));
						if(encrypt_decrypt = '0') then
						  state <= UPDATE_STATE;
						else
						  state <= COMPARE_MAC; 
						end if;
					end if;
				else 
					state <= GET_MAC;
				end if;
             
            WHEN OP_GET_MAC =>
				mac_from_message(15+(16*to_integer(unsigned(mac_count))) downto 16*to_integer(unsigned(mac_count))) <= Q_s;
				report "Q_s: " & to_hstring(Q_s);
                state <= WAIT_GET_MAC;
                
			WHEN WAIT_GET_MAC =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_GET_MAC;
				else
					state <= WAIT_LATCH_GET_MAC;
				end if;

            WHEN WAIT_LATCH_GET_MAC =>
                if(completed_c = '1') then
                    TAG((15+(16*to_integer(unsigned(mac_count)))) downto (16*to_integer(unsigned(mac_count)))) <= data_16_out_c;
                    state <= GET_MAC;
					
					 
					 
					 mac_count := std_logic_vector(unsigned(mac_count) + to_unsigned(1, 8));
                else
                    state <= WAIT_LATCH_GET_MAC;
                end if;
                
 ---------------COMPARE MAC------------------------------------
            WHEN COMPARE_MAC =>
				
                if(TAG = MAC_from_message)then
					-- authenticated
				 else
					ct <= (others=>(others=>'0'));
				 end if;
                state <= UPDATE_STATE;      
----------------UPDATE STATE------------------------------------
            when UPDATE_STATE =>
                interrupt <= '1';
                state 	  <= WAIT_ACK;
 
            when WAIT_ACK =>
                if(enable = '1' and ack = '1') then
                    interrupt       <= '0';
                    state           <= WRITE_CT;
                    crypt_count := std_logic_vector(to_unsigned(0, 10));
                end if;
-----------------WRITE THE MESSAGE ENCRYPTED/DECRYPTED IN OUTPUT---------------------------------------------------
			
			WHEN LOAD_CT_RAM =>
				Address_ct <= std_logic_vector(to_unsigned(to_integer(unsigned(crypt_count)), 4));
				state <= WAIT_LOAD_CT_RAM;
			
			WHEN WAIT_LOAD_CT_RAM =>
				state <= WRITE_CT;
			
			WHEN WRITE_CT =>
				if(completed_c = '1') then
					if(to_integer(unsigned(crypt_count)) < to_integer(unsigned(lenght_submsg))) then
						data_out <= swapsb(Q_s(15 downto 8)) & swapsb(Q_s(7 downto 0));
						buffer_enable <= '1';
						address <= std_logic_vector(to_unsigned(to_integer(unsigned(crypt_count))/2 + to_integer(unsigned(msg_address_decode)), ADD_WIDTH));
						rw <= '1';
						error <= '0';
						state <= OP_WRITE_CT;
					else
						crypt_count := std_logic_vector(to_unsigned(0, 10));
						state <= WRITE_MAC;
					end if;
				else
					state <= WRITE_CT;
				end if;
            
            WHEN OP_WRITE_CT =>
                state <= WAIT_WRITE_CT;
                
			WHEN WAIT_WRITE_CT =>
				if(enable = '1') then
					data_out <= swapsb(ct(to_integer(unsigned(crypt_count))+ 1)) & swapsb(ct(to_integer(unsigned(crypt_count))));
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(crypt_count))/2 + to_integer(unsigned(msg_address_decode)), ADD_WIDTH));
					rw <= '1';
					error <= '0';
					crypt_count := std_logic_vector(to_unsigned(2, 10) + unsigned(crypt_count));
					state <= LOAD_CT_RAM;
				else
					state <= WAIT_WRITE_CT;
				end if;
-----------------WRITE MAC--------------------------------------            
			WHEN WRITE_MAC =>
				if(completed_c = '1') then
					if(to_integer(unsigned(mac_count)) = 0) then
						buffer_enable <= '1';
						rw <= '1';
						address <= std_logic_vector(to_unsigned(to_integer(unsigned(mac_count)) + to_integer(unsigned(msg_address_decode)) + 4, ADD_WIDTH));
						data_out <= swapsb(TAG((15+(16*to_integer(unsigned(mac_count)))) downto 8+(16*to_integer(unsigned(mac_count))))) & swapsb(TAG((7+(16*to_integer(unsigned(mac_count)))) downto (16*to_integer(unsigned(mac_count)))));
						error <= '0';
						state <= OP_WRITE_MAC;
					elsif(to_integer(unsigned(mac_count)) > 0 and to_integer(unsigned(mac_count)) < 4) then
						buffer_enable <= '1';
						rw <= '1';
						address <= std_logic_vector(to_unsigned(to_integer(unsigned(mac_count)) + to_integer(unsigned(msg_address_decode)) + 4, ADD_WIDTH));
						data_out <= swapsb(TAG((15+(16*to_integer(unsigned(mac_count)))) downto 8+(16*to_integer(unsigned(mac_count))))) & swapsb(TAG((7+(16*to_integer(unsigned(mac_count)))) downto (16*to_integer(unsigned(mac_count)))));
						error <= '0';
						state <= OP_WRITE_MAC;
					else
						mac_count := std_logic_vector(to_unsigned(0, 8));
						state <= CLEAR_ALL;
					end if;
				else
					state <= WRITE_MAC;
				end if;
            
            WHEN OP_WRITE_MAC =>
                state <= WAIT_WRITE_MAC;
                
			WHEN WAIT_WRITE_MAC =>
				if(enable = '1') then
					data_out <= swapsb(TAG((15+(16*to_integer(unsigned(mac_count)))) downto 8+(16*to_integer(unsigned(mac_count))))) & swapsb(TAG((7+(16*to_integer(unsigned(mac_count)))) downto (16*to_integer(unsigned(mac_count)))));
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(to_integer(unsigned(mac_count)) + to_integer(unsigned(msg_address_decode)) + 4, ADD_WIDTH));
					rw <= '1';
					error <= '0';
					mac_count := std_logic_vector(to_unsigned(1, 8) + unsigned(mac_count));
					state <= WRITE_MAC;
				else
					state <= WAIT_WRITE_MAC;
				end if;				
-------------------------------------------------------------------				
			WHEN CLEAR_ALL =>
				data_out <= (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				error <= '0';
				state <= DONE;

			WHEN DONE =>
				if(enable = '0') then
					state <= OFF;
				else
					state <= DONE;
				end if;
			
			WHEN OTHERS =>
				state <= OFF;
			end case;
	end if;
end process;
end Behavioral;