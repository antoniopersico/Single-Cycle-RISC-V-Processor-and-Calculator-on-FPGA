library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MMIO_Decoder is
    Port (
        clk              : in  STD_LOGIC;
        reset            : in  STD_LOGIC;  

        -- CPU side
        Address          : in  STD_LOGIC_VECTOR(31 downto 0);  -- data address (ALUResult)
        WriteData        : in  STD_LOGIC_VECTOR(31 downto 0);  -- value written by sw
        MemWrite         : in  STD_LOGIC;                      -- write enable from the CPU
        ReadData         : out STD_LOGIC_VECTOR(31 downto 0);  -- value returned to lw

        -- Data memory side
        DataMem_ReadData : in  STD_LOGIC_VECTOR(31 downto 0);  -- word read from the RAM
        DataMem_WE       : out STD_LOGIC;                      -- RAM write enable

        -- Physical peripherals
        Switches         : in  STD_LOGIC_VECTOR(15 downto 0);
        Buttons          : in  STD_LOGIC_VECTOR(4 downto 0);   -- debounced buttons
        Seg_Data         : out STD_LOGIC_VECTOR(31 downto 0)   -- value shown on the display
    );
end MMIO_Decoder;

architecture Behavioral of MMIO_Decoder is
    -- Display register: keeps the last value written to 0x200
    signal seg_reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    -- Free-running counter read at 0x400
    signal random_counter : unsigned(15 downto 0) := (others => '0');
begin

    -- Read multiplexer
    process(Address, DataMem_ReadData, Switches, Buttons, random_counter)
    begin
        if Address = x"00000100" then
            -- Switches
            ReadData <= x"0000" & Switches;
        elsif Address = x"00000300" then
            -- Buttons
            ReadData <= x"000000" & "000" & Buttons;
        elsif Address = x"00000400" then
            -- Random number: current value of the counter
            ReadData <= x"0000" & std_logic_vector(random_counter);
        else
            -- Everything else: RAM data
            ReadData <= DataMem_ReadData;
        end if;
    end process;

    -- Registers: display register and random counter
    process(clk, reset)
    begin
        if reset = '0' then
            seg_reg <= (others => '0');
            random_counter <= (others => '0');
        elsif rising_edge(clk) then
            random_counter <= random_counter + 1;
            if MemWrite = '1' then
                if Address = x"00000200" then
                    -- sw to the display address: store the value
                    seg_reg <= WriteData;
                end if;
            end if;
        end if;
    end process;

    -- Register content goes to the 7-segment driver
    Seg_Data <= seg_reg;

    -- RAM write enable
    DataMem_WE <= '1' when (MemWrite = '1' and unsigned(Address) < x"000000FF") else '0';

end Behavioral;