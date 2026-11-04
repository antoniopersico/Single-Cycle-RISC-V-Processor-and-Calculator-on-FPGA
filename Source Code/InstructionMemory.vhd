
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity InstructionMemory is
    Port (
        instr_addr  : in  STD_LOGIC_VECTOR(31 downto 0);  -- address from the PC
        instruction : out STD_LOGIC_VECTOR(31 downto 0)   -- instruction read
    );
end InstructionMemory;

architecture Behavioral of InstructionMemory is
    type rom_type is array (0 to 63) of STD_LOGIC_VECTOR(31 downto 0);
    signal ROM : rom_type := (
        -- MAIN PROGRAM 
        0 => x"00000193", -- addi x3, x0, 0       x3 = 0 
        1 => x"20302023", -- sw   x3, 512(x0)     display x3
        2 => x"00000063", -- beq  x0, x0, 0       idle loop

        -- idx 3-15 are unused
        
        -- INTERRUPT SERVICE ROUTINE (idx 16 = address 0x40, hard-wired in RISCV_Core)
        -- Registers: x3 accumulator, x4 buttons, x1 operand, x6 mode, x5/x7 temporaries

        -- Read the inputs
        16 => x"30002203", -- lw   x4, 768(x0)     x4 = buttons (0x300)
        17 => x"0A020063", -- beq  x4, x0, +160    x4 = 0: no button pressed (release), jump to mret (idx 57)
        18 => x"10002083", -- lw   x1, 256(x0)     x1 = switches (0x100)

        -- Split the switches
        19 => x"00E00393", -- addi x7, x0, 14      x7 = 14 (shift amount)
        20 => x"0070D333", -- srl  x6, x1, x7      
        21 => x"00100293", -- addi x5, x0, 1       
        22 => x"007292B3", -- sll  x5, x5, x7      
        23 => x"FFF28293", -- addi x5, x5, -1      x5 = 0x3FFF (mask)
        24 => x"0050F0B3", -- and  x1, x1, x5      

        -- Direction buttons Logic (right 1, left 2, down 4, up 8)
        25 => x"00100293", -- addi x5, x0, 1       x5 = 1 (right button)
        26 => x"02520063", -- beq  x4, x5, +32     right pressed: jump to AND (idx 34)
        27 => x"00200293", -- addi x5, x0, 2       x5 = 2 (left button)
        28 => x"02520063", -- beq  x4, x5, +32     left pressed: jump to OR (idx 36)
        29 => x"00400293", -- addi x5, x0, 4       x5 = 4 (down button)
        30 => x"02520063", -- beq  x4, x5, +32     down pressed: jump to SUB (idx 38)
        31 => x"00800293", -- addi x5, x0, 8       x5 = 8 (up button)
        32 => x"02520063", -- beq  x4, x5, +32     up pressed: jump to ADD (idx 40)

        33 => x"02000263", -- beq  x0, x0, +36     no direction matched (center button): jump to the center logic (idx 42)

        -- Operations
        34 => x"0011F1B3", -- and  x3, x3, x1
        35 => x"04000A63", -- beq  x0, x0, +84     jump to idx 56(write on the 7-segments)
        36 => x"0011E1B3", -- or   x3, x3, x1
        37 => x"04000663", -- beq  x0, x0, +76     jump to idx 56
        38 => x"401181B3", -- sub  x3, x3, x1
        39 => x"04000263", -- beq  x0, x0, +68     jump to idx 56
        40 => x"001181B3", -- add  x3, x3, x1
        41 => x"02000E63", -- beq  x0, x0, +60     jump to idx 56

        -- Center Button Logic
        42 => x"00030C63", -- beq  x6, x0, +24     mode 0: jump to XOR (idx 48)
        43 => x"00100393", -- addi x7, x0, 1       x7 = 1
        44 => x"00730C63", -- beq  x6, x7, +24     mode 1: jump to SRL (idx 50)
        45 => x"00200393", -- addi x7, x0, 2       x7 = 2
        46 => x"00730C63", -- beq  x6, x7, +24     mode 2: jump to SLL (idx 52)
        47 => x"00000E63", -- beq  x0, x0, +28     otherwise mode 3: jump to the random number (idx 54)

        -- Center Button Operations
        48 => x"0011C1B3", -- xor  x3, x3, x1
        49 => x"00000E63", -- beq  x0, x0, +28     jump to idx 56 (write on the 7-segments)
        50 => x"0011D1B3", -- srl  x3, x3, x1
        51 => x"00000A63", -- beq  x0, x0, +20     jump to idx 56
        52 => x"001191B3", -- sll  x3, x3, x1
        53 => x"00000663", -- beq  x0, x0, +12     jump to idx 56
        54 => x"40002183", -- lw   x3, 1024(x0)    x3 = random counter (0x400)
        55 => x"00000263", -- beq  x0, x0, +4      jumps to the next instruction

        -- END OF THE ISR
        56 => x"20302023", -- sw   x3, 512(x0)    
        57 => x"30200073", -- mret                 

        others => x"00000000" 
    );
begin
    instruction <= ROM(to_integer(unsigned(instr_addr(7 downto 2))));

end Behavioral;