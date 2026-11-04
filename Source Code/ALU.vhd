library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU is
    Port (
        SrcA       : in  STD_LOGIC_VECTOR(31 downto 0);
        SrcB       : in  STD_LOGIC_VECTOR(31 downto 0);
        ALUControl : in  STD_LOGIC_VECTOR(2 downto 0);
        ALUResult  : out STD_LOGIC_VECTOR(31 downto 0);
        Zero       : out STD_LOGIC
    );
end ALU;

architecture Behavioral of ALU is
    signal result_internal : STD_LOGIC_VECTOR(31 downto 0);
begin
    
    process(SrcA, SrcB, ALUControl)
    begin
        case ALUControl is
            when "000" => -- AND
                result_internal <= SrcA and SrcB;
                
            when "001" => -- OR
                result_internal <= SrcA or SrcB;
                
            when "010" => -- ADD (used also for addi, lw, sw. For lw and sw used to calculate address)
                result_internal <= std_logic_vector(signed(SrcA) + signed(SrcB));
                
            when "011" => -- XOR
                result_internal <= SrcA xor SrcB;
                
            when "100" => -- SLL
                result_internal <= std_logic_vector(shift_left(unsigned(SrcA), to_integer(unsigned(SrcB(4 downto 0)))));
                
            when "101" => -- SRL
                result_internal <= std_logic_vector(shift_right(unsigned(SrcA), to_integer(unsigned(SrcB(4 downto 0)))));
                
            when "110" => -- SUB (used also for beq)
                result_internal <= std_logic_vector(signed(SrcA) - signed(SrcB));
                
            when "111" => -- SLT (Set Less Than)
                if signed(SrcA) < signed(SrcB) then
                    result_internal <= x"00000001";
                else
                    result_internal <= (others => '0');
                end if;
                
            when others =>
                result_internal <= (others => '0');
        end case;
    end process;

    ALUResult <= result_internal;
    Zero <= '1' when result_internal = x"00000000" else '0';

end Behavioral;