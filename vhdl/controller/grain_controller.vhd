----------------------------------------------------------------------------------
-- Created by: GIUSEPPE CARRUBBA / NICOL� BIANCO
-- Create Date: 12.09.2021
-- Module Name: grain_controller
-- Project Name: Lightweight cipher
-- Version: 1.0
-- Additional Comments: 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.CONSTANTS.all;

entity grain_controller is
	port(   --IP MANAGER SIGNALS
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
				   WAIT_CORE_SR_NEXT_Z,
				   
				   INIT_CORE_SR_LOAD,
				   OP_INIT_CORE_SR_LOAD,
				   WAIT_CORE_SR_LOAD,
				   
				   TAG_NEXT_Z,
				   OP_TAG_NEXT_Z,
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
				   
				   CIPHER_ACCUMULATE,
				   OP_CIPHER_ACCUMULATE,
				   WAIT_CIPHER_ACCUMULATE,
				   
				   CIPHER_LOAD_SR,
				   OP_CIPHER_LOAD_SR,
				   WAIT_CIPHER_LOAD_SR,
				   
				   GENERATE_USELESS_NEXT_Z,
				   OP_USELESS_NEXT_Z,
				   WAIT_USELESS_NEXT_Z,
				   
				   USELESS_ACCUMULATE,
				   OP_USELESS_ACCUMULATE,
				   WAIT_USELESS_ACCUMULATE,
				   
				   GET_MAC,
				   OP_GET_MAC,
				   WAIT_GET_MAC,
				   
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

signal OPCODE_REG : std_logic_vector(5 downto 0);

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

--REGS
signal CW      		 : std_logic_vector(15  downto 0);
--type IV_mem is array (7 downto 0) of std_logic_vector(15 downto 0);
--signal IV     		 : iv_mem;
signal IV : std_logic_vector(127 downto 0);
--type key_mem is array (7 downto 0) of std_logic_vector(15 downto 0);
--signal key           : key_mem;
signal key : std_logic_vector(127 downto 0);
signal lenght_submsg : std_logic_vector(7   downto 0);
signal lenght_AD     : std_logic_vector(7   downto 0);
--type AD_mem is array (9 downto 0) of std_logic_vector(15 downto 0);
--signal AD            : AD_mem;
signal AD : std_logic_vector(159 downto 0);
--type Msg_mem is array (60 downto 0) of std_logic_vector(15 downto 0);
--signal MSG 			 : Msg_mem;
--signal CT 			 : Msg_mem; --signal to store the cipher text
signal MSG : std_logic_vector(959 downto 0);
signal CT  : std_logic_vector(959 downto 0);
--type TAG_mem is array (3 downto 0) of std_logic_vector(15 downto 0);
--signal TAG		 : TAG_mem;
signal TAG : std_logic_vector(63 downto 0);

signal tmp_sig : integer := 0;

begin

core: grain128_core port map (clock, rst_c, data_16_in_c, data_16_addr_in_c, serial_data_in_c, start_c,
                              operation_c, grain_round_c, data_16_out_c, serial_data_out_c,
	                          completed_c, busy_c);

------------------------------------------------------------------------
process (clock, reset)

variable key_count   		  : integer := 0;
variable iv_count    		  : integer := 0;
variable ad_count    		  : integer := 0;
variable msg_count   	      : integer := 0;
variable msg_address_decode   : integer := 0; 	--Variable used to address message based on init packet or message packet.
variable lenght_adress_decode : integer := 0; 	--Variable used to address lenght of message on init packet or messagge packet.
variable pre_output_count     : integer := 0; 	--Variable that let runs the core 256 times to load stuff
variable acc_count			  : integer := 127; --variable to initialize auth_acc inside the core
variable tag_count			  : integer := 0;	--Variable to accumulate tag and loop between states
variable crypt_count		  : integer := 0;
variable ac_count			  : integer :=0; --variable to index the message during encryption/decryption
variable mac_count			  : integer :=0; 
variable wc_count             : integer :=0;
variable debug : std_logic_vector(0 downto 0) := "0";
begin
	if(reset = '1') then
		--CORE SIGNALS
		set_init_core <= '0';
		rst_c <= '1';
		data_16_in_c <= (others => '0');
		data_16_addr_in_c <= (others => '0');
		serial_data_in_c <= '0';
		start_c <= '0';
		operation_c <= (others => '0');
		grain_round_c <= (others => '0');

		--registers at 0
		CW 		      <= (others => '0');
		--IV 			  <= (others => (others=>'0'));
		IV 		      <= (others => '0');
		--KEY 		  <= (others => (others=>'0'));
		KEY 		      <= (others => '0');
		lenght_submsg <= (others => '0');
		lenght_AD     <= (others => '0');
		--AD  		  <= (others => (others => '0'));
		AD 		      <= (others => '0');
		--MSG 		  <= (others => (others => '0'));
		MSG 		      <= (others => '0');
		--CT 			  <= (others => (others => '0'));
		CT 		      <= (others => '0');
		--TAG           <= (others => (others => '0'));
		TAG 		  <= (others => '0');
		OPCODE_REG    <= (others=>'0');
		key_count := 0;
		iv_count := 0;
		ad_count := 0;
		msg_count := 0;
		msg_address_decode := 0;
		lenght_adress_decode := 0;
		pre_output_count := 0;
		acc_count := 127;
		tag_count := 0;
		crypt_count := 0;
		ac_count := 0;
		wc_count := 0;
	elsif(rising_edge(clock)) then
		case (state) is
----------------OFF STATE------------------------------------------------------------------------------
			when OFF =>
				--CORE SIGNALS
				rst_c <= '0';
				data_16_in_c <= (others => '0');
				data_16_addr_in_c <= (others => '0');
				serial_data_in_c <= '0';
				start_c <= '0';
				operation_c <= (others => '0');
				grain_round_c <= (others => '0');
				wc_count := 0;
				NEXT_Z_reg <= '0';
				----------------------------
				data_out <=  (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
			    if(enable = '1') then
			    	state <= WAIT_CW;
			    else
			    	state <= OFF;
			    end if;
-------------------READ CW---------------------------------------------------------------------------
			when WAIT_CW =>
				--CORE SIGNALS
				rst_c <= '0';
				data_16_in_c <= (others => '0');
				data_16_addr_in_c <= (others => '0');
				serial_data_in_c <= '0';
				start_c <= '0';
				operation_c <= (others => '0');
				grain_round_c <= (others => '0');
				----------------------------
				if(write_completed = '1') then
				    wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
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
				--CORE SIGNALS
				rst_c <= '0';
				data_16_in_c <= (others => '0');
				data_16_addr_in_c <= (others => '0');
				serial_data_in_c <= '0';
				start_c <= '0';
				operation_c <= (others => '0');
				grain_round_c <= (others => '0');
				----------------------------
				state <= READ_CW;

			WHEN READ_CW =>
				--CORE SIGNALS
				rst_c <= '0';
				data_16_in_c <= (others => '0');
				data_16_addr_in_c <= (others => '0');
				serial_data_in_c <= '0';
				start_c <= '0';
				operation_c <= (others => '0');
				grain_round_c <= (others => '0');
				----------------------------
				CW <= data_in;
				data_out <= (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				state <= DECODE_OPCODE;
---------------------EVALUATE PACKET ORGANIZATION------------------------------------------------------------------------
			WHEN DECODE_OPCODE =>
				case CW(15 downto 10) is
					when "000000" => --init encrypt
						state <= WAIT_KEY;
						msg_address_decode := 28;
						lenght_adress_decode := 17;
						set_init_core <= '1';
					when "000001" => --encrypt message
						msg_address_decode := 1;
						lenght_adress_decode := 0;
						state <= WAIT_LENGTH;
						set_init_core <= '0';
					when "000010" => --init decrypt
						state <= WAIT_KEY;
						msg_address_decode := 28;
						lenght_adress_decode := 17;
						set_init_core <= '1';
					when "000011" => --decrypt message
						msg_address_decode := 1;
						lenght_adress_decode := 0;
						set_init_core <= '0';
						state <= WAIT_LENGTH;
					when OTHERS =>
						state <= OFF;
				end case;
--------------------READING KEY-------------------------------------------------------------------------
		    when WAIT_KEY =>
		    	if(write_completed = '1' OR wc_count>(1+key_count)) then 
		    	    wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(key_count+1, ADD_WIDTH));
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
		    	key((15+(16*key_count)) downto (16*key_count)) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(key_count < 7) then
					key_count := key_count+1;
					state <= WAIT_KEY;
			    else
			    	key_count := 0;
			    	state <= WAIT_IV;
			    end if;
-------------------READING INITIALIZTION VECTOR-----------------------------------------------------------------------
		    WHEN WAIT_IV =>
		    	if(write_completed = '1' OR wc_count>(1+8+IV_count)) then 
					wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(IV_count+1+8, ADD_WIDTH));
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
				IV((15+(16*iv_count)) downto (16*iv_count)) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(iv_count < 7) then
					iv_count := iv_count+1;
					state <= WAIT_IV;
			    else
			    	iv_count := 0;
			    	state <= WAIT_LENGTH;
			    end if;
--------------READING LENGHT OF ASSOCIATED DATA AND MESSAGE----------------------------------------------------------------
		    WHEN WAIT_LENGTH =>
		    	if(write_completed = '1' OR wc_count>(1+8+8+1)) then
					wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(lenght_adress_decode, ADD_WIDTH)); 
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
				lenght_submsg <= data_in(15 downto 8); --to swap in case with AD
				lenght_AD <= data_in(7 downto 0);  --it depends on how data is passed
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
				if(write_completed = '1' OR wc_count> (1+8+8+1+AD_count)) then 
					wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(AD_count+18, ADD_WIDTH));
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
				AD((15+(16*AD_count)) downto (16*AD_count)) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(AD_count <= to_integer(unsigned(lenght_AD)) ) then
				    tmp_sig <= tmp_sig + 1;
					ad_count := ad_count+1;
					state <= WAIT_AD;
			    else
			    	ad_count := 0;
			    	state <= WAIT_MSG;
			    end if;
------------------READING MESSAGE------------------------------------------------------------
			 
			 WHEN WAIT_MSG =>
				if(write_completed = '1' OR wc_count> (1+8+8+1+to_integer(unsigned(lenght_AD)) + MSG_count)) then 
					wc_count := wc_count + 1;
				    report "wc_count: " & integer'image(wc_count);
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(MSG_count+msg_address_decode, ADD_WIDTH));
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
				MSG((15+(16*MSG_count)) downto (16*MSG_count)) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(MSG_count <= to_integer(unsigned(lenght_submsg)) ) then
					MSG_count := MSG_count+1;
					state <= WAIT_MSG;
			    else
			    	MSG_count := 0;
			    	if(set_init_core = '1') then
			    		state <= INIT_CORE_IV;
			    	else
			    		state <= CIPHER_NEXT_Z;
			    	end if;
			    end if;
----------------INITIALIZATION VECTOR CORE---------------------------------------------------
			WHEN INIT_CORE_IV =>
				if(completed_c = '1') then
					if(iv_count <= 7) then
						start_c <= '1';
						operation_c <= LOAD_IV;
						data_16_in_c <= IV((15+(16*iv_count)) downto (16*iv_count));
						data_16_addr_in_c <= std_logic_vector(to_unsigned(IV_count, 3));
						state <= OP_INIT_CORE_IV;
					else
						iv_count := 0;
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
				    iv_count := iv_count + 1;
					state <= INIT_CORE_IV;
				end if;
-------------------INIT READING KEY CORE-------------------------------------------------------
			WHEN INIT_CORE_KEY =>
				if(completed_c = '1') then
					if(key_count <= 7) then
						start_c <= '1';
						operation_c <= LOAD_KEY;
						data_16_in_c <= KEY((15+(16*key_count)) downto (16*key_count));
						data_16_addr_in_c <= std_logic_vector(to_unsigned(key_count, 3));
						report "keycount:" & integer'image(key_count);
						state <= OP_INIT_CORE_KEY;
					else
						key_count := 0;
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
				    key_count := key_count + 1;
					state <= INIT_CORE_KEY;
				end if;
-----------------RUN FOR PREPARE OUTPUT---------------------------------------------------
		    WHEN INIT_CORE_PRE_OUTPUT =>
		    	IF(completed_c = '1') then
		    		if(pre_output_count <= 255) then
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
		    			pre_output_count := 0;
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
				    pre_output_count := pre_output_count + 1;
					state <= INIT_CORE_PRE_OUTPUT;
				end if;
---------------------LOADING ACCUMULATOR-------------------------------------------------------
			WHEN INIT_CORE_ACC_NEXT_Z =>
				if(completed_c = '1') then
					if(acc_count > 64) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						serial_data_in_c <= KEY(acc_count);
						debug(0) := KEY(acc_count);
						--report "Key_bit[" & integer'image(acc_count/16) & "][" & integer'image(acc_count mod 16) & "]:" & integer'image(to_integer(unsigned(debug)));
						state <= OP_INIT_CORE_ACC_NEXT_Z;
					else
						acc_count := 63;
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
				    acc_count := acc_count - 1;
					state <= INIT_CORE_ACC_NEXT_Z;
				end if;
------------------LOADING SHIFT REGISTER-----------------------------------------------------
			WHEN INIT_CORE_SR_NEXT_Z =>
				if(completed_c = '1') then
					if(acc_count >= 0) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						serial_data_in_c <= KEY(acc_count);
						state <= OP_INIT_CORE_SR_NEXT_Z;
					else
						acc_count := 0;
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
					NEXT_Z_reg <= serial_data_out_c;
					state <= INIT_CORE_SR_LOAD;
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
					acc_count := acc_count - 1;
					state <= INIT_CORE_SR_NEXT_Z;
				end if;
---------------ACCUMULATE TAG--------------------------------------------------------------------
			WHEN TAG_NEXT_Z =>
				if(completed_c = '1') then
					if(tag_count < to_integer(unsigned(lenght_AD))*2) then
					    report "tag_count: " & integer'image(tag_count);
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_TAG_NEXT_Z;
					else
						tag_count := 0;
						ad_count := 0;
						state <= CIPHER_NEXT_Z;
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
					NEXT_Z_reg <= serial_data_out_c;
					state <= TAG_ACCUMULATE;
				end if;

			WHEN TAG_ACCUMULATE =>
				if(completed_c = '1') then
					if( ( (tag_count)mod 2) /= 0 ) then
					    --report "tag_count mod 2 != 0";
						--if(AD ((to_integer(unsigned(lenght_AD)) - ad_count)/16) ((to_integer(unsigned(lenght_AD)) - ad_count)mod 16) = '1') then
						    if(AD(to_integer(unsigned(lenght_AD)) - AD_count) = '1') then
							--report "ad=1";
							start_c <= '1';
							operation_c <= ACCUMULATE;
							state <= OP_TAG_ACCUMULATE;
					    else
					       report "ad=0";
					       state <= TAG_LOAD_SR;
						end if;
				    else
				        state <= OP_TAG_ACCUMULATE;
				        --report "tag_count mod 2 == 0";
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
			         tag_count := tag_count + 1;
			         ad_count := ad_count + 1;
			         state <= TAG_NEXT_Z;
			     end if;
			
--------------ENCRYPTION/DECRYPTION-----------------------------------------------
			WHEN CIPHER_NEXT_Z =>
				if(completed_c = '1') then
					if(crypt_count < to_integer(unsigned(lenght_submsg))*2 ) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= OP_CIPHER_NEXT_Z;
					else
						crypt_count := 0;
						msg_count := 0;
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
					NEXT_Z_reg <= serial_data_out_c;
					state <= CIPHER_ACCUMULATE;
				end if;

			WHEN CIPHER_ACCUMULATE =>
				if(completed_c = '1') then
					if((crypt_count mod 2) = 0) then
						--CT ((to_integer(unsigned(lenght_submsg)) - 1 - msg_count)/16) ((to_integer(unsigned(lenght_submsg)) - 1 - msg_count) mod 16) <= MSG((to_integer(unsigned(lenght_submsg)) - 1 - msg_count)/16) ((to_integer(unsigned(lenght_submsg)) - 1 - msg_count) mod 16) xor NEXT_Z_reg;
						CT(to_integer(unsigned(lenght_submsg)) -1 - msg_count) <= msg(to_integer(unsigned(lenght_submsg)) -1 - msg_count) xor NEXT_Z_reg;
						msg_count := msg_count + 1;
						state <= CIPHER_LOAD_SR;
					else
						--if( MSG((to_integer(unsigned(lenght_submsg)) - 1 - msg_count)/16) ((to_integer(unsigned(lenght_submsg)) - 1 - msg_count) mod 16) = '1') then
						if(MSG(to_integer(unsigned(lenght_submsg)) -1 - msg_count) = '1') then
							operation_c <= ACCUMULATE;
							start_c <= '1';
							state <= OP_CIPHER_ACCUMULATE;
						else
						    state <= CIPHER_LOAD_SR;
						end if;
						ac_count := ac_count + 1;
					end if;
				else
					state <= CIPHER_ACCUMULATE;
				end if;
            
            WHEN OP_CIPHER_ACCUMULATE =>
                state <= WAIT_CIPHER_ACCUMULATE;
                
			WHEN WAIT_CIPHER_ACCUMULATE =>
				start_c <= '0'; -- remember to move start for other wait statement
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
					crypt_count := crypt_count + 1;
					state <= CIPHER_NEXT_Z;
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
----------------------GIVE THE AUTHENTICATION IN OUTPUT--------------------------------------------------------
			WHEN GET_MAC =>
				if(completed_c = '1') then
					if(mac_count < 4) then
						operation_c <= READ_AUTH_ACC;
						data_16_addr_in_c <= std_logic_vector(to_unsigned(mac_count, 3));
						start_c <= '1';
						state <= OP_GET_MAC;
					else 
						mac_count := 0;
						state <= WRITE_MAC;
					end if;
				else 
					state <= GET_MAC;
				end if;
            
            WHEN OP_GET_MAC =>
                state <= WAIT_GET_MAC;
                
			WHEN WAIT_GET_MAC =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_GET_MAC;
				else
					TAG((15+(16*mac_count)) downto (16*mac_count)) <= data_16_out_c;
					mac_count := mac_count + 1;
					state <= GET_MAC;
				end if;

			WHEN WRITE_MAC =>
				if(write_completed = '1') then
					if(mac_count = 0) then
						buffer_enable <= '1';
						rw <= '1';
						address <= std_logic_vector(to_unsigned(1+mac_count, ADD_WIDTH));
						data_out <= TAG((15+(16*mac_count)) downto (16*mac_count));
						interrupt <= '1';
						error <= '0';
						state <= OP_WRITE_MAC;
					elsif(mac_count > 0 and mac_count < 4) then
						buffer_enable <= '1';
						rw <= '1';
						address <= std_logic_vector(to_unsigned(1+mac_count, ADD_WIDTH));
						data_out <= TAG((15+(16*mac_count)) downto (16*mac_count));
						interrupt <= '0';
						error <= '0';
						state <= OP_WRITE_MAC;
					else
						mac_count := 0;
						state <= WRITE_CT;
					end if;
				else
					state <= WRITE_MAC;
				end if;
            
            WHEN OP_WRITE_MAC =>
                state <= WAIT_WRITE_MAC;
                
			WHEN WAIT_WRITE_MAC =>
				if(ack = '1' and enable = '1') then
					data_out <= TAG((15+(16*mac_count)) downto (16*mac_count));
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(1+mac_count, ADD_WIDTH));
					rw <= '1';
					interrupt <= '0';
					error <= '0';
					mac_count := mac_count + 1;
					state <= WRITE_MAC;
				else
					state <= WAIT_WRITE_MAC;
				end if;
-----------------GIVE THE MESSAGE ENCRYPTED/DECRYPTED IN OUTPUT---------------------------------------------------
			WHEN WRITE_CT =>
				if(write_completed = '1') then
					if(crypt_count < to_integer(unsigned(lenght_submsg))) then
						data_out <= CT((15+(16*crypt_count)) downto (16*crypt_count));
						buffer_enable <= '1';
						address <= std_logic_vector(to_unsigned(crypt_count+5, ADD_WIDTH));
						rw <= '1';
						interrupt <= '0';
						error <= '0';
						state <= OP_WRITE_CT;
					else
						crypt_count := 0;
						state <= CLEAR_ALL;
					end if;
				else
					state <= WRITE_CT;
				end if;
            
            WHEN OP_WRITE_CT =>
                state <= WAIT_WRITE_CT;
                
			WHEN WAIT_WRITE_CT =>
				if(ack = '1' and enable = '1') then
					data_out <= CT((15+(16*crypt_count)) downto (16*crypt_count));
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(5+crypt_count, ADD_WIDTH));
					rw <= '1';
					interrupt <= '0';
					error <= '0';
					crypt_count := crypt_count + 1;
					state <= WRITE_CT;
				else
					state <= WAIT_WRITE_CT;
				end if;

			WHEN CLEAR_ALL =>
				data_out <= (others => '0');
				buffer_enable <= '0';
				address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
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