library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.to_unsigned;
use ieee.numeric_std.to_integer;
use ieee.numeric_std.unsigned;
use ieee.numeric_std.shift_left;

entity grain128_tb is
end grain128_tb;

architecture Behavioral of grain128_tb is

--Swap the significant bits in a single byte
function swapsb(byte : std_logic_vector(7 downto 0)) return std_logic_vector is
variable return_vector : std_logic_vector(7 downto 0);
begin
    for k in 0 to 7 loop
        return_vector(k) := byte(7-k);
    end loop;
    return return_vector;
end swapsb;

component grain128_core is
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

signal clk_s             : std_logic := '0';
signal rst_s             : std_logic;
signal data_16_in_s     : std_logic_vector(15 downto 0);
signal data_16_addr_in   : std_logic_vector(2 downto 0);
signal serial_data_in_s  : std_logic;
signal start_s           : std_logic;
signal operation_s       : std_logic_vector(2 downto 0);
signal grain_round_s     : std_logic_vector(1 downto 0);
signal data_16_out_s     : std_logic_vector(15 downto 0);
signal serial_data_out_s : std_logic;
signal completed_S       : std_logic;
signal busy_s            : std_logic;

signal key : std_logic_vector(127 downto 0) := X"80C4A2E691D5B3F7482C6A1E593D7B0F";
signal iv : std_logic_vector(127 downto 0) := X"80C4A2E691D5B3F7482C6A1EFFFFFFFE";

signal msg : std_logic_vector(64 downto 0) := "11100011010010110100001101111011001110110101001101000010010000100";
signal ad : std_logic_vector(23 downto 0) := "010000001000100010001000";
signal ciphertext : std_logic_vector(63 downto 0) := (others=>'0');
signal ciphertext_swapped : std_logic_vector(63 downto 0) := (others=>'0');
signal tag : std_logic_vector(63 downto 0) := (others=>'0');
signal tag_swapped : std_logic_vector(63 downto 0) := (others=>'0');
signal final_ct : std_logic_vector(127 downto 0) := (others=>'0');
begin

DUT: grain128_core port map (clk_s, rst_s, data_16_in_s, data_16_addr_in, serial_data_in_s, start_s, operation_s, grain_round_s, data_16_out_s, serial_data_out_s, completed_S, busy_s);

ClkProc:process(clk_s)
begin
    clk_s <= not(clk_s) after 10 ns;
end process ClkProc;

VectProc:process
variable data_16_out_variable : std_logic_vector(15 downto 0);
variable next_z_output : std_Logic;
variable next_z_output_vector : std_logic_vector(0 downto 0); 
variable msg_i_vector : std_logic_vector(0 downto 0);
variable m_cnt, ac_cnt, c_cnt, ad_cnt : integer := 0;
variable acc_counter, shift_value : integer := 0;
variable adval, compare_value : std_logic_vector(7 downto 0) := (others=>'0');
variable adval_bit : std_logic := '0';
begin
    --RESET
    data_16_in_s <= (others=>'0'); data_16_addr_in <= (others =>'0'); serial_data_in_s <= '0'; start_s <= '0'; operation_s <= "000"; grain_round_s <= "00";
    rst_s <= '1';
    
    wait until rising_edge(clk_s);
    --READY TO OPERATE
    rst_s <= '0';
     
    --Wait until the cipher is ready
    wait until completed_s = '1' and completed_s'event; 
    
    --Load IV (PARALLEL LOAD)
    for k in 0 to 7 loop
        operation_s <= "000"; --Load IV
        data_16_in_s <= iv(15+(16*k) downto (16*k));
        data_16_addr_in <= std_logic_vector(to_unsigned(k, 3));
        --Start the loading of IV
        start_s <= '1';
        
        wait until rising_edge(busy_s);
        start_s <= '0';
        
        wait until rising_edge(completed_s);
    end loop;
    
    
    --Load KEY (PARALLEL LOAD)
    for k in 0 to 7 loop
        operation_s <= "001"; --Load KEY
        data_16_in_s <= key(15+(16*k) downto (16*k));
        data_16_addr_in <= std_logic_vector(to_unsigned(k, 3));
        --Start the loading of the KEY
        start_s <= '1';
        
        wait until rising_edge(busy_s);
        start_s <= '0';
        
        wait until rising_edge(completed_s);
    end loop;
    
    wait for 10 ns;
    
    --Let the cipher run for 256 times, next_z(0) INIT
    for k in 0 to 255 loop
        operation_s <= "010"; --Next z
        grain_round_s <= "00"; --INIT
        start_s <= '1';
        --report "Loop iteration: " & integer'image(k);
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        wait for 10 ns;
    end loop;
    
    --Initialize the auth_acc and auth_sr 
    --auth_acc
    for k in 127 downto 64 loop
        -- First generate the next_s value 
        operation_s <= "010"; -- next_z
        grain_round_s <= "01"; -- ADDKEY
        serial_data_in_s <= key(k);
        start_s <= '1';
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        next_z_output := serial_data_out_s;
        
        wait for 10 ns;
        
        --Then Load the auth_acc
        serial_data_in_s <= next_z_output;
        operation_s <= "011"; -- load_auth_acc
        serial_data_in_s <= next_z_output;
        
        start_s <= '1';
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        
    end loop;
    
    --auth_sr
    for k in 63 downto 0 loop
        -- First generate the next_s value 
        operation_s <= "010"; -- next_z
        grain_round_s <= "01"; -- ADDKEY
        serial_data_in_s <= key(k);
        start_s <= '1';
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        next_z_output := serial_data_out_s;
        
        wait for 10 ns;
        
        --Then Load the auth_sr
        serial_data_in_s <= next_z_output;
        operation_s <= "100"; -- load_auth_sr
        serial_data_in_s <= next_z_output;
        
        start_s <= '1';
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        
    end loop;
    
    --Accumulate TAG
      for k in 0 to (ad'LENGTH / 8)-1 loop
        for j in 0 to 15 loop
        -- First generate the next_s value 
            operation_s <= "010"; -- next_z
            grain_round_s <= "10"; -- NORMAL
            serial_data_in_s <= '0';
            start_s <= '1';
            wait until busy_s = '1' and busy_s'event; 
            start_s <= '0';
            
            wait until completed_s = '1' and completed_s'event; 
            next_z_output := serial_data_out_s;
            --next_z_output_vector(0) := next_z_output;
            --report "k: " & integer'image(k) & " next_z: " & integer'image(to_integer(unsigned(next_z_output_vector)));
            
            if(j mod 2 = 0)then
                --Donothing
            else
                report "Ad_cnt : " & integer'image(ad_cnt);
                if(ad(((ad'LENGTH - 1)) - ad_cnt) = '1')then
                     --Accumulate
                    operation_s <= "101"; -- accumulate
                    start_s <= '1';
                    wait until busy_s = '1' and busy_s'event; 
                    start_s <= '0';
                    
                    wait until completed_s = '1' and completed_s'event; 
                    acc_counter := acc_counter + 1;
                end if;
                --Shift in the z_next vvalue in the auth_sr
                operation_s <= "100"; -- load_sr
                serial_data_in_s <= next_z_output;
                start_s <= '1';
                wait until busy_s = '1' and busy_s'event; 
                start_s <= '0';
                
                wait until completed_s = '1' and completed_s'event;
                ad_cnt := ad_cnt + 1;
            end if;
        end loop;
      end loop;
    report "Acc counter : " & integer'image(acc_counter);
    
    m_cnt := 0;
    ac_cnt := 0;
    
    --Encrypt
    for k in 0 to 127 loop
        -- First generate the next_s value 
        operation_s <= "010"; -- next_z
        grain_round_s <= "10"; -- NORMAL
        serial_data_in_s <= '0';
        start_s <= '1';
        wait until busy_s = '1' and busy_s'event; 
        start_s <= '0';
        
        wait until completed_s = '1' and completed_s'event; 
        next_z_output := serial_data_out_s;
        next_z_output_vector(0) := next_z_output;
        --report "Encrypt: k: " & integer'image(k) & " next_z: " & integer'image(to_integer(unsigned(next_z_output_vector)));
        
        if((k mod 2) = 0)then
            -- Generate keystream
            ciphertext(63-m_cnt) <= msg(63-m_cnt) xor next_z_output;
            msg_i_vector(0) := msg(63-m_cnt);
            report "i: " & integer'image(m_cnt) & " - msg(i): " & integer'image(to_integer(unsigned(msg_i_vector))) & " - next_z: " & integer'image(to_integer(unsigned(next_z_output_vector)));
            m_cnt := m_cnt + 1;
            c_cnt := c_cnt + 1;
        else 
            if(msg(63-ac_cnt) = '1') then
                --Accumulate
                report "Accumulating - ac_cnt: " & integer'image(ac_cnt);
                operation_s <= "101"; -- accumulate
                start_s <= '1';
                wait until busy_s = '1' and busy_s'event; 
                start_s <= '0';
                
                wait until completed_s = '1' and completed_s'event; 
            end if;
             ac_cnt := ac_cnt + 1;
            --Shift in the z_next vvalue in the auth_sr
            operation_s <= "100"; -- load_sr
            serial_data_in_s <= next_z_output;
            start_s <= '1';
            wait until busy_s = '1' and busy_s'event; 
            start_s <= '0';
            
            wait until completed_s = '1' and completed_s'event;
        end if;
    end loop;
    
    --Swap the ct
    for k in 0 to 7 loop
        ciphertext_swapped(7+(8*k) downto (8*k)) <= swapsb(ciphertext(7+(8*k) downto (8*k)));
    end loop;
    
    --Generate unused keystream bit next_z
    operation_s <= "010"; -- next_z
    grain_round_s <= "10"; -- NORMAL
    serial_data_in_s <= '0';
    start_s <= '1';
    wait until busy_s = '1' and busy_s'event; 
    start_s <= '0';
    
    wait until completed_s = '1' and completed_s'event;
    
    --Accumulate
    operation_s <= "101"; -- accumulate
    start_s <= '1';
    wait until busy_s = '1' and busy_s'event; 
    start_s <= '0';
    
    wait until completed_s = '1' and completed_s'event; 
    
    --get MAC
    for k in 0 to 3 loop
        operation_s <= "110"; -- read_auth_acc
        data_16_addr_in <= std_logic_vector(to_unsigned(k, 3));
        --Start 
        start_s <= '1';
        
        wait until rising_edge(busy_s);
        start_s <= '0';
        
        wait until rising_edge(completed_s);
        data_16_out_variable := data_16_out_s;
        
        tag(15+(16*k) downto (16*k)) <= data_16_out_variable;
        wait for 10 ns;
    end loop;
    
    --Swap the mac
    for k in 0 to 7 loop
        report integer'image(to_integer(unsigned(swapsb(tag(7+(8*k) downto (8*k))))));
        tag_swapped(7+(8*k) downto (8*k)) <= swapsb(tag(7+(8*k) downto (8*k)));
    end loop;
    
    wait for 10 ns;
    
    final_ct(127 downto 64) <= ciphertext_swapped;
    final_ct(63 downto 0) <= tag_swapped;
    wait;
end process VectProc;
end Behavioral;
