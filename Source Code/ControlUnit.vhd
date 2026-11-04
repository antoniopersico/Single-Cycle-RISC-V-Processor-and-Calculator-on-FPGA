library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ControlUnit is
    Port (
        Op       : in  STD_LOGIC_VECTOR(6 downto 0);
        Branch   : out STD_LOGIC;
        ResultSrc: out STD_LOGIC;
        MemWrite : out STD_LOGIC;
        ALUSrc   : out STD_LOGIC;
        ImmSrc   : out STD_LOGIC_VECTOR(1 downto 0);
        RegWrite : out STD_LOGIC;
        ALUOp    : out STD_LOGIC_VECTOR(1 downto 0)
    );
end ControlUnit;

architecture Behavioral of ControlUnit is
begin
    process(Op)
    begin
        -- default values
        Branch    <= '0';
        ResultSrc <= '0';
        MemWrite  <= '0';
        ALUSrc    <= '0';
        ImmSrc    <= "00";
        RegWrite  <= '0';
        ALUOp     <= "00";

        case Op is
            when "0110011" => -- Type R (add, sub, and, or, xor, sll, srl, slt)
                RegWrite  <= '1';
                ALUOp     <= "10";

            when "0010011" => -- Type I (addi, andi, ori, xori, slli, srli, slti)
                ALUSrc    <= '1';
                RegWrite  <= '1';
                ImmSrc    <= "00";
                ALUOp     <= "11";

            when "0000011" => -- lw
                ALUSrc    <= '1';
                ResultSrc <= '1';
                RegWrite  <= '1';
                ImmSrc    <= "00";
                ALUOp     <= "00";

            when "0100011" => -- sw
                ALUSrc    <= '1';
                MemWrite  <= '1';
                ImmSrc    <= "01";
                ALUOp     <= "00";

            when "1100011" => -- beq 
                Branch    <= '1';
                ImmSrc    <= "10";
                ALUOp     <= "01";

            when others =>
                -- keep default values
        end case;
    end process;
end Behavioral;