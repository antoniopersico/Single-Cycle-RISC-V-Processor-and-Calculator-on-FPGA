library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ALUDecoder is
    Port (
        ALUOp      : in  STD_LOGIC_VECTOR(1 downto 0);
        funct3     : in  STD_LOGIC_VECTOR(2 downto 0);
        funct7_5   : in  STD_LOGIC; -- Instruction BIT (30)
        ALUControl : out STD_LOGIC_VECTOR(2 downto 0)
    );
end ALUDecoder;

architecture Behavioral of ALUDecoder is
begin
    process(ALUOp, funct3, funct7_5)
    begin
        case ALUOp is
            when "00" => 
                -- Type  Load/Store (lw, sw): the ALU adds base address and offset
                ALUControl <= "010"; -- ADD
                
            when "01" => 
                -- Type Branch (beq): the ALU does a subtraction for comparison (Zero = 1)
                ALUControl <= "110"; -- SUB
                
            when "10" | "11" => 
                -- Type R (10) or Type I (11) (arithmetic-logical operations)
                case funct3 is
                    when "000" =>
                        -- We distinguish between ADD and SUB only if it is a Type R statement 
                        if ALUOp = "10" and funct7_5 = '1' then
                            ALUControl <= "110"; -- SUB
                        else
                            ALUControl <= "010"; -- ADD
                        end if;
                        
                    when "100" => 
                        ALUControl <= "011"; -- XOR
                        
                    when "110" => 
                        ALUControl <= "001"; -- OR
                        
                    when "111" => 
                        ALUControl <= "000"; -- AND
                        
                    when "010" => 
                        ALUControl <= "111"; -- SLT 
                        
                    when "001" =>
                        ALUControl <= "100"; -- SLL 
                        
                    when "101" =>
                        ALUControl <= "101"; -- SRL 
                        
                    when others => 
                        ALUControl <= "000"; -- Safety Value
                end case;
                
            when others =>
                ALUControl <= "000"; -- Default value
        end case;
    end process;
end Behavioral;