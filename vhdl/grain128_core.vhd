library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity grain128_core is
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
end grain128_core;

architecture Behavioral of grain128_core is

--Utility functions
function next_lfsr_fb(lfsr : std_logic_vector(127 downto 0)) return std_logic is
begin
    --return (lfsr(96) xor lfsr(81) xor lfsr(70) xor lfsr(38) xor lfsr(7) xor lfsr(0));  127-
    return (lfsr(31) xor lfsr(46) xor lfsr(57) xor lfsr(89) xor lfsr(120) xor lfsr(127));
end next_lfsr_fb;

function next_nfsr_fb(nfsr : std_logic_vector(127 downto 0)) return std_logic is
begin
    return (nfsr(127-96) xor nfsr(127-91) xor nfsr(127-56) xor nfsr(127-26) xor nfsr(127-0) xor (nfsr(127-84) and nfsr(127-68)) xor
			(nfsr(127-67) and nfsr(127-3)) xor (nfsr(127-65) and nfsr(127-61)) xor (nfsr(127-59) and nfsr(127-27)) xor
			(nfsr(127-48) and nfsr(127-40)) xor (nfsr(127-18) and nfsr(127-17)) xor (nfsr(127-13) and nfsr(127-11)) xor
			(nfsr(127-82) and nfsr(127-78) and nfsr(127-70)) xor (nfsr(127-25) and nfsr(127-24) and nfsr(127-22)) xor
			(nfsr(127-95) and nfsr(127-93) and nfsr(127-92) and nfsr(127-88)));
end next_nfsr_fb;

function next_h(lfsr, nfsr : std_logic_vector(127 downto 0)) return std_logic is
begin
    return ((nfsr(127-12) and lfsr(127-8)) xor (lfsr(127-13) and lfsr(127-20)) xor (nfsr(127-95) and lfsr(127-42)) xor (lfsr(127-60) and lfsr(127-79)) xor
            (nfsr(127-12) and nfsr(127-95) and lfsr(127-94)));
end next_h;

function nfsr_tmp(nfsr: std_logic_vector(127 downto 0)) return std_logic is
begin
    return (nfsr(127-2) xor nfsr(127-15) xor nfsr(127-36) xor nfsr(127-45) xor nfsr(127-64) xor nfsr(127-73) xor nfsr(127-89));
end nfsr_tmp;

signal lfsr, nfsr : std_logic_vector(127 downto 0);
signal auth_sr, auth_acc : std_logic_vector(63 downto 0);

signal data_16_in_i : std_logic_vector(15 downto 0);
signal data_16_addr_in_i : std_logic_vector(2 downto 0);
signal operation_i : std_logic_vector(2 downto 0);
signal grain_round_i : std_logic_vector(1 downto 0);
signal serial_data_in_i : std_logic;

type Statetype is (OFF, SELECT_OP, LOAD_KEY, LOAD_IV, NEXT_Z, LOAD_AUTH_ACC, LOAD_AUTH_SR, ACCUMULATE, READ_AUTH_ACC, DONE);
signal state : Statetype;


begin

process(clk)
variable y, out_i : std_logic;
--variable out_i_vector, shift_lfsr_vector, shift_nfsr_vector : std_logic_vector(0 downto 0); 

begin
    if(rst = '1') then
        state <= OFF;
        lfsr <= (others=>'0');
        nfsr <= (others=>'0');
        auth_sr <= (others=>'0');
        auth_acc <= (others=>'0');
        operation_i <= (others=>'0');
        grain_round_i <= (others=>'0');
    elsif(rising_edge(clk)) then
        case state is
            when OFF =>
                        serial_data_out <= '0';
                        completed <= '1';
                        busy <= '0';
                        if(start = '1')then
                            data_16_in_i <= data_16_in;
                            data_16_addr_in_i <= data_16_addr_in;
                            operation_i <= operation;
                            grain_round_i <= grain_round;
                            serial_data_in_i <= serial_data_in;
                            state <= SELECT_OP;
                        else
                            state <= OFF;
                        end if;
            when SELECT_OP =>
                        busy <= '1';
                        case operation_i is
                            when "000" => state <= LOAD_IV; 
                            when "001" => state <= LOAD_KEY; 
                            when "010" => state <= NEXT_Z; 
                            when "011" => state <= LOAD_AUTH_ACC;
                            when "100" => state <= LOAD_AUTH_SR;
                            when "101" => state <= ACCUMULATE;
                            when "110" => state <= READ_AUTH_ACC;
                            when others => state <= OFF;                  
                        end case;
                        serial_data_out <= '0'; 
                        completed <= '0';
            when LOAD_IV =>
                        busy <= '1';
                        serial_data_out <= '0'; 
                        completed <= '0';
                        lfsr(15+(16*to_integer(unsigned(data_16_addr_in_i))) downto (16*to_integer(unsigned(data_16_addr_in_i)))) <= data_16_in_i;
                        state <= DONE;
                        
            when LOAD_KEY => 
                        busy <= '1';
                        serial_data_out <= '0'; 
                        completed <= '0';
                        nfsr(15+(16*to_integer(unsigned(data_16_addr_in_i))) downto (16*to_integer(unsigned(data_16_addr_in_i)))) <= data_16_in_i;
                        state <= DONE;
            when NEXT_Z =>
                        busy <= '1';
                        y := (next_h(lfsr, nfsr) xor lfsr(127-93) xor nfsr_tmp(nfsr));
                        case grain_round_i is
                            when "00" => --INIT
                                         out_i := lfsr(127); 
                                         lfsr <= lfsr(126 downto 0) & (next_lfsr_fb(lfsr) xor y);
                                         nfsr <= nfsr(126 downto 0) & (next_nfsr_fb(nfsr) xor out_i xor y);
                                         
                            when "01" => --ADDKEY
                                         out_i := lfsr(127);           
                                         lfsr <= lfsr(126 downto 0) & (next_lfsr_fb(lfsr) xor serial_data_in_i);
                                         nfsr <= nfsr(126 downto 0) & (next_nfsr_fb(nfsr) xor out_i);
                            when "10" => --NORMAL
                                         out_i := lfsr(127);           
                                         lfsr <= lfsr(126 downto 0) & (next_lfsr_fb(lfsr));
                                         nfsr <= nfsr(126 downto 0) & (next_nfsr_fb(nfsr) xor out_i);
                            when others => 
                            
                        end case;   
                        serial_data_out <= y;
                        completed <= '0';
                        state <= DONE;
            when LOAD_AUTH_ACC => busy <= '1';
                                  auth_acc <= auth_acc(62 downto 0) & serial_data_in_i;
                                  serial_data_out <= '0';
                                  completed <= '0';
                                  state <= DONE;
                                    
            when LOAD_AUTH_SR =>  busy <= '1';
                                  auth_sr <= auth_sr(62 downto 0) & serial_data_in_i;
                                  serial_data_out <= '0';
                                  completed <= '0';
                                  state <= DONE;
                                  
            when ACCUMULATE   =>  busy <= '1';
                                  --report "Auth_acc: " & to_hstring(auth_acc) & "\n Auth_sr: " & to_hstring(auth_sr);
                                  auth_acc <= auth_acc xor auth_sr;
                                  serial_data_out <= '0';
                                  completed <= '0';
                                  state <= DONE;
           
            when READ_AUTH_ACC => --report "ACC_MAC: " & integer'image(to_integer(unsigned(auth_acc))) & " - " & to_hstring(auth_acc) & "h";
                                  busy <= '1';
                                  data_16_out <= auth_acc(15+(16*to_integer(unsigned(data_16_addr_in_i))) downto (16*to_integer(unsigned(data_16_addr_in_i))));
                                  serial_data_out <= '0';
                                  completed <= '0';
                                  state <= DONE;                                                                      
            when DONE =>
                                  busy <= '1';
                                  completed <= '1';
                                  state <= OFF;
        end case;
    end if;
    
    
end process;



end Behavioral;

