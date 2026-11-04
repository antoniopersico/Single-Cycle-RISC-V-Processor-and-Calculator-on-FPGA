library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ProgramCounter is
    Port (
        clk    : in  STD_LOGIC;
        reset  : in  STD_LOGIC;
        pc_in  : in  STD_LOGIC_VECTOR(31 downto 0);
        pc_out : out STD_LOGIC_VECTOR(31 downto 0)
    );
end ProgramCounter;

architecture Behavioral of ProgramCounter is
begin
    process(clk, reset)
    begin
        if reset = '0' then
            pc_out <= (others => '0'); -- On reset it starts again from address 0x00000000
        elsif rising_edge(clk) then
            pc_out <= pc_in;           -- Load the next address
        end if;
    end process;
end Behavioral;