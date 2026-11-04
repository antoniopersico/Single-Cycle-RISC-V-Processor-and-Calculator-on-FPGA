-- RISCV_Core.vhd
-- Single-cycle RISC-V core with a simple interrupt mechanism.
-- It connects the fetch, decode, execute and write-back blocks and computes the next PC.
-- Data memory and peripherals are outside the core (MMIO_Decoder): the core exposes the
-- data address (ALUResult), the data to write (WriteData) and MemWrite, and takes ReadData back.
-- Interrupt: a one-cycle irq pulse sends the PC to the ISR at 0x40, mepc keeps the return
-- address and mret (0x30200073) jumps back to it.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RISCV_Core is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;                   
        irq         : in  STD_LOGIC;                      -- interrupt request from the button debouncers
        ReadData    : in  STD_LOGIC_VECTOR(31 downto 0);  -- data read 
        ALUResult   : out STD_LOGIC_VECTOR(31 downto 0);  
        WriteData   : out STD_LOGIC_VECTOR(31 downto 0);  -- value of rs2
        MemWrite    : out STD_LOGIC                       -- write enable for memory and peripherals
    );
end RISCV_Core;

architecture Structural of RISCV_Core is

    -- Fetch
    signal PC, PCNext, PCPlus4, PCTarget : STD_LOGIC_VECTOR(31 downto 0);
    signal Instr                         : STD_LOGIC_VECTOR(31 downto 0);

    -- Control signals
    signal RegWrite, ALUSrc              : STD_LOGIC;
    signal ResultSrc, Branch, PCSrc, Zero: STD_LOGIC;
    signal ImmSrc, ALUOp                 : STD_LOGIC_VECTOR(1 downto 0);
    signal ALUControl                    : STD_LOGIC_VECTOR(2 downto 0);
    -- Write enables 
    signal RegWrite_raw, MemWrite_raw    : STD_LOGIC;

    -- Datapath
    signal ImmExt                        : STD_LOGIC_VECTOR(31 downto 0);
    signal SrcA, SrcB                    : STD_LOGIC_VECTOR(31 downto 0);
    signal Result                        : STD_LOGIC_VECTOR(31 downto 0);
    
    
    signal WriteData_int                 : STD_LOGIC_VECTOR(31 downto 0);
    signal ALUResult_int                 : STD_LOGIC_VECTOR(31 downto 0);

    -- Interrupt
    signal irq_take                      : STD_LOGIC;                      -- interrupt accepted in this cycle
    signal in_isr                        : STD_LOGIC := '0';               -- 1 while the ISR is running
    signal mepc                          : STD_LOGIC_VECTOR(31 downto 0);  -- return address of the interrupted instruction
    signal is_mret                       : STD_LOGIC;                      -- current instruction is mret

begin

    -- Output ports
    WriteData <= WriteData_int;
    ALUResult <= ALUResult_int;

    
    -- Interrupt handling
    
    -- An irq is accepted only if the ISR is not already running (no nested interrupts)
    irq_take <= irq and not in_isr;

    -- mret is recognised by comparing the whole instruction
    is_mret <= '1' when Instr = x"30200073" else '0';

    -- On irq_take: save the PC of the interrupted instruction and enter the ISR.
    -- On mret: leave the ISR, so new interrupts are accepted again.
    process(clk, reset)
    begin
        if reset = '0' then
            mepc   <= (others => '0');
            in_isr <= '0';
        elsif rising_edge(clk) then
            if irq_take = '1' then
                mepc   <= PC;
                in_isr <= '1';
            elsif is_mret = '1' then
                in_isr <= '0';
            end if;
        end if;
    end process;

    -- The instruction running when the interrupt is accepted must have no effect:
    -- it will be executed again after mret (mepc points to it)
    RegWrite <= RegWrite_raw and not irq_take;
    MemWrite <= MemWrite_raw and not irq_take;

    -- Next PC
    PCPlus4  <= std_logic_vector(unsigned(PC) + 4);
    PCTarget <= std_logic_vector(unsigned(PC) + unsigned(ImmExt));  -- branch target
    PCSrc    <= Branch and Zero;                                    -- beq taken

    -- Priority: interrupt, mret, taken branch, sequential execution
    PCNext   <= x"00000040" when irq_take = '1' else  -- jump to the ISR
                mepc        when is_mret = '1' else   -- return from the ISR
                PCTarget    when PCSrc = '1' else     -- taken branch
                PCPlus4;                              -- next instruction

    -- Datapath multiplexers
    -- Second ALU operand: immediate or register rs2
    SrcB   <= ImmExt when ALUSrc = '1' else WriteData_int;
    -- Value written back to the register file: data memory/peripheral or ALU result
    Result <= ReadData when ResultSrc = '1' else ALUResult_int;

    -- Components
    u_PC: entity work.ProgramCounter
        port map (clk => clk, reset => reset, pc_in => PCNext, pc_out => PC);

    u_InstrMem: entity work.InstructionMemory
        port map (instr_addr => PC, instruction => Instr);

    u_MainControl: entity work.ControlUnit
        port map (
            Op => Instr(6 downto 0), Branch => Branch, ResultSrc => ResultSrc,
            MemWrite => MemWrite_raw, ALUSrc => ALUSrc, ImmSrc => ImmSrc,
            RegWrite => RegWrite_raw, ALUOp => ALUOp
        );

    u_ALUDecoder: entity work.ALUDecoder
        port map (
            ALUOp => ALUOp, funct3 => Instr(14 downto 12),
            funct7_5 => Instr(30), ALUControl => ALUControl
        );

    u_RegisterFile: entity work.RegisterFile
        port map (
            clk => clk, we3 => RegWrite,
            rs1 => Instr(19 downto 15), rs2 => Instr(24 downto 20), rd => Instr(11 downto 7),
            wd3 => Result, rd1 => SrcA, rd2 => WriteData_int
        );

    u_ImmGen: entity work.ImmGen
        port map (Instr => Instr(31 downto 7), ImmSrc => ImmSrc, ImmExt => ImmExt);

    u_ALU: entity work.ALU
        port map (
            SrcA => SrcA, SrcB => SrcB, ALUControl => ALUControl,
            ALUResult => ALUResult_int, Zero => Zero
        );

end Structural;