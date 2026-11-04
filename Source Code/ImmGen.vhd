library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ImmGen is
    Port (
        Instr  : in  STD_LOGIC_VECTOR(31 downto 7);
        ImmSrc : in  STD_LOGIC_VECTOR(1 downto 0);
        ImmExt : out STD_LOGIC_VECTOR(31 downto 0)
    );
end ImmGen;

architecture Behavioral of ImmGen is
begin
    process(Instr, ImmSrc)
    begin
        case ImmSrc is
            when "00" => 
                -- Type I (lw, addi): 12 bit Immediate
                ImmExt <= std_logic_vector(resize(signed(Instr(31 downto 20)), 32));
                
            when "01" => 
                -- Type S (sw): 12 bit Immediate
                ImmExt <= std_logic_vector(resize(signed(Instr(31 downto 25) & Instr(11 downto 7)), 32));
                
            when "10" => 
                -- Type B (beq): 13 bit Immediate
                ImmExt <= std_logic_vector(resize(signed(Instr(31) & Instr(7) & Instr(30 downto 25) & Instr(11 downto 8) & '0'), 32));
                
            when others => 
                ImmExt <= (others => '0');
        end case;
    end process;
end Behavioral;