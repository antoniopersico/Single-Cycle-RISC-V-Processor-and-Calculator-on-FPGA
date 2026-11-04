library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DataMemory is
    Port (
        clk : in  STD_LOGIC;
        we  : in  STD_LOGIC;                      -- Write Enable
        address   : in  STD_LOGIC_VECTOR(31 downto 0);  -- Adress 
        wd  : in  STD_LOGIC_VECTOR(31 downto 0);  -- Data to write 
        rd  : out STD_LOGIC_VECTOR(31 downto 0)   -- Data read
    );
end DataMemory;

architecture Behavioral of DataMemory is
    -- 64 word RAM (32 bits each)
    type ram_type is array (0 to 63) of STD_LOGIC_VECTOR(31 downto 0);
    signal RAM : ram_type := (others => (others => '0'));
begin

    -- Asynchronous reading: data exits immediately based on address
    rd <= RAM(to_integer(unsigned(address(7 downto 2))));

    -- Synchronous writing on the rising edge of the clock
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM(to_integer(unsigned(address(7 downto 2)))) <= wd;
            end if;
        end if;
    end process;

end Behavioral;