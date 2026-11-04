library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RegisterFile is
    Port (
        clk : in  STD_LOGIC;
        we3 : in  STD_LOGIC;                      -- Write Enable
        rs1  : in  STD_LOGIC_VECTOR(4 downto 0);   -- Source Register 1 
        rs2  : in  STD_LOGIC_VECTOR(4 downto 0);   -- Source Register 2 
        rd  : in  STD_LOGIC_VECTOR(4 downto 0);   -- Destination Register
        wd3 : in  STD_LOGIC_VECTOR(31 downto 0);  -- Write Data
        rd1 : out STD_LOGIC_VECTOR(31 downto 0);  -- Read Data 1
        rd2 : out STD_LOGIC_VECTOR(31 downto 0)   -- Read Data 2
    );
end RegisterFile;

architecture Behavioral of RegisterFile is
    -- 32 registers of 32 bits
    type ram_type is array (0 to 31) of STD_LOGIC_VECTOR(31 downto 0);
    signal registers : ram_type := (others => (others => '0'));
begin

    -- Asynchronous reading
    rd1 <= x"00000000" when rs1 = "00000" else registers(to_integer(unsigned(rs1)));
    rd2 <= x"00000000" when rs2 = "00000" else registers(to_integer(unsigned(rs2)));

    -- Synchronous writing
    process(clk)
    begin
        if rising_edge(clk) then
            -- Write only if Write Enable is 1 and rd is not x0
            if we3 = '1' and rd /= "00000" then
                registers(to_integer(unsigned(rd))) <= wd3;
            end if;
        end if;
    end process;

end Behavioral;