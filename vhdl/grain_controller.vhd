library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.CONSTANTS.all;

entity grain_controller is
	port(   --IP MANAGER
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
			--IP CORE
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


           		      COMPUTEs0,   -- LOAD LSFR 
                      COMPUTEs1,   -- LOAD NFSR
                      COMPUTEs2,   -- PRODUCE NEXT_Z
                      COMPUTEs3,   -- LOAD ACC
                      COMPUTEs4,   -- LOAD SR
                      COMPUTEs5,   -- ACCUMULATE
                      COMPUTEs6,   -- 

                       when "000" => state <= LOAD_IV; 
                            when "001" => state <= LOAD_KEY; 
                            when "010" => state <= NEXT_Z; 
                            when "011" => state <= LOAD_AUTH_ACC;
                            when "100" => state <= LOAD_AUTH_SR;
                            when "101" => state <= ACCUMULATE;
                            when "110" => state <= READ_AUTH_ACC;

           		   ACK_WAITING, 
           		   WAIT_STATUS_CPU,
           	       WRITE_RESULT,
                   WRITE_STATUS, 
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

signal OPCODE : std_logic_vector(5 downto 0);

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
type IV_mem is array of (7 downto 0) of std_logic_vector(15 downto 0);
signal IV     		 : iv_mem;
type key_mem is array of (7 downto 0) of std_logic_vector(15 downto 0);
signal key           : key_mem;
signal lenght_submsg : std_logic_vector(7   downto 0);
signal lenght_AD     : std_logic_vector(7   downto 0);
type AD_mem is array of (9 downto 0) of std_logic_vector(15 downto 0);
signal AD            : AD_mem;
type Msg_mem is array of (60 downto 0) of std_logic_vector(15 downto 0);
signal MSG 			 : Msg_mem;
signal CT 			 : Msg_mem; --signal to store the cipher text
type TAG_mem is array of (3 downto 0) of std_logic_vector(15 downto 0);
signal TAG		 : TAG_mem;

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
		IV 			  <= (others => '0');
		KEY 		  <= (others => '0');
		lenght_submsg <= (others => '0');
		lenght_AD     <= (others => '0');
		AD  		  <= (others => (others => '0'));
		MSG 		  <= (others => (others => '0'));
		CT 			  <= (others => (others => '0'));
		TAG           <= (others => (others => '0'));
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
	elsif(rising_edge(clk)) then
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
				----------------------------
				data_out <=  (others => '0');
				buffer_enable <= '0'';
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
						msg_address_decode := 27;
						lenght_adress_decode := 17;
						set_init_core <= '1';
					when "000001" => --encrypt message
						msg_address_decode := 0;
						lenght_adress_decode := 0;
						state <= WAIT_LENGTH;
						set_init_core <= '0';
					when "000010" => --init decrypt
						state <= WAIT_KEY;
						msg_address_decode := 27;
						lenght_adress_decode := 17;
						set_init_core <= '1';
					when "000011" => --decrypt message
						msg_address_decode := 0;
						lenght_adress_decode := 0;
						set_init_core <= '0';
						state <= WAIT_LENGTH;
				end case;
--------------------READING KEY-------------------------------------------------------------------------
		    when WAIT_KEY =>
		    	if(write_completed = '1') then 
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
		    	key(key_count) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(key_count < 8) then
					key_count := key_count+1;
					state <= WAIT_KEY;
			    else
			    	key_count := 0;
			    	state <= WAIT_IV;
			    end if;
-------------------READING INITIALIZTION VECTOR-----------------------------------------------------------------------
		    WHEN WAIT_IV =>
		    	if(write_completed = '1') then 
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
				IV(iv_count) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(iv_count < 8) then
					iv_count := iv_count+1;
					state <= WAIT_IV;
			    else
			    	iv_count := 0;
			    	state <= WAIT_LENGTH;
			    end if;
--------------READING LENGHT OF ASSOCIATED DATA AND MESSAGE----------------------------------------------------------------
		    WHEN WAIT_LENGTH =>
		    	if(write_completed = '1') then
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
				if(write_completed = '1') then 
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(AD_count+1+18, ADD_WIDTH));
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
				AD(AD_count) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(AD_count < to_integer(lenght_AD)) then
					ad_count := ad_count+1;
					state <= WAIT_AD;
			    else
			    	ad_count := 0;
			    	state <= WAIT_MSG;
			    end if;
------------------READING MESSAGE------------------------------------------------------------
			 
			 WHEN WAIT_MSG =>
				if(write_completed = '1') then 
					buffer_enable <= '1';
					address <= std_logic_vector(to_unsigned(MSG_count+1+msg_address_decode, ADD_WIDTH));
					data_out <= (others => '0'); 
					rw <= '0';
					interrupt <= '0';
					error <= '0';
					state <= ADDR_AD;
				else
					state <= WAIT_AD;
				end if;

			WHEN ADDR_MSG =>
				state <= READ_AD;

			WHEN READ_MSG =>
				MSG(MSG_count) <= data_in;
		    	data_out <= (others => '0');
		    	buffer_enable <= '0';
		    	address <= (others => '0');
				rw <= '0';
				interrupt <= '0';
				error <= '0';
				if(MSG_count < to_integer(lenght_msg)) then
					MSG_count := MSG_count+1;
					state <= MSG_count;
			    else
			    	MSG_count := 0;
			    	if(set_init_core = '1') then
			    		state <= INIT_CORE_IV;
			    	else
			    		state <= COMPUTEs0;
			    	end if;
			    end if;
----------------INITIALIZATION VECTOR CORE---------------------------------------------------
			WHEN INIT_CORE_IV =>
				if(completed_c = '1') then
					if(iv_count < 8) then
						start_c <= '1'';
						operation_c <= LOAD_IV;
						data_16_in_c <= IV(iv_count);
						data_16_addr_in_c <= std_logic_vector(to_unsigned(IV_count, 3));
						iv_count := iv_count + 1;
						state <= WAIT_CORE_IV;
					else
						iv_count := 0;
						state <= INIT_CORE_KEY;
					end if;
				else
					state <= INIT_CORE_IV;
				end if;

			WHEN WAIT_CORE_IV =>
				if(busy_c = '1') then
					start <= '0';
					state <= WAIT_CORE_IV;
				else
					state <= INIT_CORE_IV;
				end if;
-------------------INIT READING KEY CORE-------------------------------------------------------
			WHEN INIT_CORE_KEY =>
				if(completed_c = '1') then
					if(key_count < 8) then
						start_c <= '1'';
						operation_c <= LOAD_KEY;
						data_16_in_c <= KEY(key_count);
						data_16_addr_in_c <= std_logic_vector(to_unsigned(key_count, 3));
						key_count := key_count + 1;
						state <= WAIT_CORE_KEY;
					else
						key_count := 0;
						state <= INIT_CORE_PRE_OUTPUT;
					end if;
				else
					state <= INIT_CORE_KEY;
				end if;

			WHEN WAIT_CORE_KEY =>
				if(busy_c = '1') then
					start <= '0';
					state <= WAIT_CORE_KEY;
				else
					state <= INIT_CORE_KEY;
				end if;
-----------------RUN FOR PREPARE OUTPUT---------------------------------------------------
		    WHEN INIT_CORE_PRE_OUTPUT =>
		    	IF(completed_c = '1') then
		    		if(pre_output_count < 256) then
		    			operation_c <= NEXT_Z;
		    			grain_round_c <= INIT;
		    			start_c <= '1';
		    			pre_output_count := pre_output_count + 1;
		    			--core signals setup
		    			data_16_in_c <= (others => '0');
		    			data_16_addr_in_c <= (others => '0');
		    			serial_data_in_c <= '0';
		    			-------------------------------------
		    			state <= WAIT_CORE_PRE_OUTPUT;
		    		else
		    			pre_output_count := 0;
		    			state <= INIT_CORE_ACC_NEXT_Z;
		    		end if;
		    	else
		    		state <= INIT_CORE_PRE_OUTPUT;
		    	end if;

		    WHEN WAIT_CORE_PRE_OUTPUT =>
				if(busy_c = '1') then
					start <= '0';
					state <= WAIT_CORE_PRE_OUTPUT;
				else
					state <= INIT_CORE_PRE_OUTPUT;
				end if;
---------------------LOADING ACCUMULATOR-------------------------------------------------------
			WHEN INIT_CORE_ACC_NEXT_Z =>
				if(completed_c = '1') then
					if(acc_count > 64) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						serial_data_in_c <= KEY(acc_count/16(acc_count mod 16));
						acc_count := acc_count - 1;
						state < WAIT_CORE_ACC_NEXT_Z;
					else
						acc_count := 63;
						state <= INIT_CORE_SR_NEXT_Z;
					end if;
				else
					state <= INIT_CORE_ACC_NEXT_Z;

			WHEN WAIT_CORE_ACC_NEXT_Z =>
				if(busy = '1') then
					start_c <= '0';
					state <= WAIT_CORE_ACC_NEXT_Z;
				else
					NEXT_Z_reg <= serial_data_out_c;
					state <= INIT_CORE_ACC_LOAD;
				end if;

			WHEN INIT_CORE_ACC_LOAD =>
				if(completed_c = '1') then
					start_c <= '1';
					operation_c <= LOAD_AUTH_ACC;
					grain_round_c <= ADD_KEY;
					serial_data_in_c <= NEXT_Z_reg;
					state <= WAIT_CORE_ACC_LOAD;
				else
					state <= INIT_CORE_ACC_LOAD;
				end if;

			WHEN WAIT_CORE_ACC_LOAD =>
				if(busy_c = '1') then
					start_c = '0';
					state <= WAIT_CORE_ACC_LOAD;
				else
					state <= INIT_CORE_ACC_NEXT_Z;
				end if;
------------------LOADING SHIFT REGISTER-----------------------------------------------------
			WHEN INIT_CORE_SR_NEXT_Z =>
				if(completed_c = '1') then
					if(acc_count >= 0) then
						operation_c <= NEXT_Z;
						grain_round_c <= ADD_KEY;
						start_c <= '1';
						serial_data_in_c <= KEY(acc_count/16(acc_count mod 16));
						acc_count := acc_count - 1;
						state < WAIT_CORE_SR_NEXT_Z;
					else
						acc_count := 0;
						--state <= TO BE DEFINED;
					end if;
				else
					state <= INIT_CORE_SR_NEXT_Z;
				end if;

			WHEN WAIT_CORE_sR_NEXT_Z =>
				if(busy = '1') then
					start_c <= '0';
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
					state <= WAIT_CORE_SR_LOAD;
				else
					state <= INIT_CORE_SR_LOAD;
				end if;

			WHEN WAIT_CORE_SR_LOAD =>
				if(busy_c = '1') then
					start_c = '0';
					state <= WAIT_CORE_SR_LOAD;
				else
					state <= INIT_CORE_SR_NEXT_Z;
				end if;
---------------ACCUMULATE TAG--------------------------------------------------------------------
			WHEN TAG_NEXT_Z =>
				if(completed_c = '1') then
					if(tag_count < to_integer(unsigned(lenght_AD))*2) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= WAIT_TAG_NEXT_Z;
					else
						tag_count := 0;
						ad_count := 0;
						state <= CIPHER_NEXT_Z;
					end if;
				else
					state <= TAG_NEXT_Z;
				end if;

			WHEN WAIT_TAG_NEXT_Z =>
				if(busy = '1') then
					start_c <= '0';
					state <= WAIT_TAG_NEXT_Z;
				else
					NEXT_Z_reg <= serial_data_out_c;
					state <= TAG_ACCUMULATE;
				end if;

			WHEN TAG_ACCUMULATE =>
				if(completed_c = '1') then
					if( ( (tag_count)mod 2) /= 0 ) then
						if(AD(((to_integer(unsigned(lenght_AD)))-AD_count)/16(((to_integer(unsigned(lenght_AD))) - AD_count) mod 16 ) ) = '1') then
							start_c <= '1';
							operation_c <= ACCUMULATE;
							tag_count := tag_count + 1;
							state <= WAIT_TAG_ACCUMULATE;
						end if;
					end if;
				else
					state <= TAG_ACCUMULATE;
				end if;

			WHEN WAIT_TAG_ACCUMULATE =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_TAG_ACCUMULATE;
				else
					AD_count := ad_count + 1;
					state <= TAG_NEXT_Z;
				end if;
--------------ENCRYPTION/DECRYPTION-----------------------------------------------
			WHEN CIPHER_NEXT_Z =>
				if(completed_c = '1') then
					if(crypt_count < to_integer(unsigned(lenght_msg))*2) then
						start_c <= '1';
						operation_c <= NEXT_Z;
						grain_round_c <= NORMAL;
						serial_data_in_c <= '0';
						state <= WAIT_CIPHER_NEXT_Z;
					else
						crypt_count := 0;
						msg_count := 0;
						state <= GENERATE_USELESS_NEXT_Z;
					end if;
				else
					state <= CIPHER_NEXT_Z;
				end if;

			WHEN WAIT_CIPHER_NEXT_Z =>
				start_c <= '0';
				if(busy_c <= '1') then
					state <= WAIT_CIPHER_NEXT_Z;
				else
					NEXT_Z_reg <= serial_data_out_c;
					state <= CIPHER_ACCUMULATE;
				end if;

			WHEN CIPHER_ACCUMULATE =>
				if(completed_c = '1') then
					if((crypt_count mod 2) = 0) then
						CT(to_integer(unsigned(lenght_msg)) - 1 - msg_count) <= MSG(to_integer(unsigned(lenght_msg))-1 - msg_count) xor NEXT_Z_reg;
						msg_count := msg_count + 1;
					else
						if(MSG(to_integer(unsigned(lenght_msg))-1 - ac_count)) then
							operation_c <= ACCUMULATE;
							start_c <= 1;
							state <= WAIT_CIPHER_ACCUMULATE;
						end if;
						ac_count := ac_count + 1;
					end if;
				else
					state <= CIPHER_ACCUMULATE;
				end if;

			WHEN WAIT_CIPHER_ACCUMULATE =>
				start_c <= '0'; -- remember to move start for other wait statement
				if(busy_c = '1') then
					state <= WAIT_CIPHER_ACCUMULATE;
				else
					state <= CIPHER_LOAD_SR;
				end if;


			WHEN CIPHER_LOAD_SR =>
				if(completed_c = '1') then
					operation_c <= LOAD_SR;
					serial_data_in_c <= NEXT_Z_reg;
					start_c <= '1';
					state  <= WAIT_CIPHER_LOAD_SR;
				else
					state <= CIPHER_LOAD_SR;
				end if;

			WHEN WAIT_CIPHER_LOAD_SR =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_CIPHER_LOAD_SR;
				else
					crypt_count := crypt_count + 1;
					state <= CIPHER_NEXT_Z;
				end if;


			WHEN GENERATE_USELESS_NEXT_Z =>
				if(completed_c = '1') then
					operation_c <= NEXT_Z;
					grain_round_c <= NORMAL;
					serial_data_in_c <= '0';
					start_c <= '1';
					state <= USELESS_ACCUMULATE;
				else
					state <= WAIT_USELESS_NEXT_Z;
				end if;

			WHEN WAIT_USELESS_NEXT_Z =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_USELESS_NEXT_Z;
				else
					state <= GENERATE_USELESS_NEXT_Z;
				end if;

			WHEN USELESS_ACCUMULATE =>
				if(completed_c = '1') then
					start_c <= '1';
					operation_c <= ACCUMULATE;
					state <= WAIT_USELESS_ACCUMULATE;
				else 
					state <= USELESS_ACCUMULATE;
				end if;

			WHEN WAIT_USELESS_ACCUMULATE =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_USELESS_ACCUMULATE;
				else 
					state <= GET_MAC;
				end if;

			WHEN GET_MAC =>
				if(completed_c = '1') then
					if(mac_count < 4) then
						operation_c <= READ_AUTH_ACC;
						data_16_addr_in_c <= std_logic_vector(to_unsigned(mac_count, 3));
						start_c <= '1';
						state <= WAIT_GET_MAC;
					else 
						mac_count := 0;
						state <= TO_BE_DEFINED;
					end if;
				else 
					state <= GET_MAC;
				end if;

			WHEN WAIT_GET_MAC =>
				start_c <= '0';
				if(busy_c = '1') then
					state <= WAIT_GET_MAC;
				else
					TAG(mac_count) <= data_16_out_c;
					mac_count := mac_count + 1;
					state <= GET_MAC;
				end if;

			WHEN TO_BE_DEFINED =>