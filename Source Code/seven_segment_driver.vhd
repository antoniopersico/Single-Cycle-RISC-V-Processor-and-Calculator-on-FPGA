library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_segment_driver is
    generic (
        -- Width of the scan counter: each digit stays for about 2.6 ms
        size : integer := 20
    );
    Port (
        clk     : in std_logic;
        reset   : in std_logic;                      
        data_in : in std_logic_vector(31 downto 0);         -- value to show: 8 hex digits
        CA, CB, CC, CD, CE, CF, CG, DP : out std_logic;     -- segment cathodes (DP = decimal point)
        AN      : out std_logic_vector(7 downto 0)          -- digit anodes
    );
end seven_segment_driver;

architecture Behavioral of seven_segment_driver is
    signal flick_counter : unsigned(size - 1 downto 0);
    signal sel_bits      : std_logic_vector(2 downto 0);    -- index of the digit (0 to 7)
    signal digit         : std_logic_vector(3 downto 0);  
    signal cathodes      : std_logic_vector(7 downto 0);    -- segment pattern of digit
begin

    -- Free-running counter that sets the scan speed
    process (clk, reset) begin
        if reset = '0' then
            flick_counter <= (others => '0');
        elsif rising_edge(clk) then
            flick_counter <= flick_counter + 1;
        end if;
    end process;

    -- The 3 most significant bits change slowly and select one of the 8 digits in turn
    sel_bits <= std_logic_vector(flick_counter(size - 1 downto size - 3));

    -- Anode: turn on only the selected digit
    with sel_bits select
        AN <= 
            "11111110" when "000", -- Digit 0 (rightmost)
            "11111101" when "001", -- Digit 1
            "11111011" when "010", -- Digit 2
            "11110111" when "011", -- Digit 3
            "11101111" when "100", -- Digit 4
            "11011111" when "101", -- Digit 5
            "10111111" when "110", -- Digit 6
            "01111111" when others; -- Digit 7 (leftmost)

    -- Pick the 4 bits of the selected digit out of the 32-bit value
    with sel_bits select
        digit <= 
            data_in(3 downto 0)   when "000",
            data_in(7 downto 4)   when "001",
            data_in(11 downto 8)  when "010",
            data_in(15 downto 12) when "011",
            data_in(19 downto 16) when "100",
            data_in(23 downto 20) when "101",
            data_in(27 downto 24) when "110",
            data_in(31 downto 28) when others;

    -- Hex digit to segments. Bit order is DP G F E D C B A.
    with digit select
        cathodes <= 
            "11000000" when "0000", -- 0
            "11111001" when "0001", -- 1
            "10100100" when "0010", -- 2
            "10110000" when "0011", -- 3
            "10011001" when "0100", -- 4
            "10010010" when "0101", -- 5
            "10000010" when "0110", -- 6
            "11111000" when "0111", -- 7
            "10000000" when "1000", -- 8
            "10010000" when "1001", -- 9
            "10001000" when "1010", -- A
            "10000011" when "1011", -- b
            "11000110" when "1100", -- C
            "10100001" when "1101", -- d
            "10000110" when "1110", -- E
            "10001110" when others; -- F

    -- Split the pattern onto the individual cathode pins
    DP <= cathodes(7);
    CG <= cathodes(6);
    CF <= cathodes(5);
    CE <= cathodes(4);
    CD <= cathodes(3);
    CC <= cathodes(2);
    CB <= cathodes(1);
    CA <= cathodes(0);

end Behavioral;