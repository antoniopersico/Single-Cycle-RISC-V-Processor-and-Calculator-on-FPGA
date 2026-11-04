-- Self-checking unit test for ControlUnit and ALUDecoder.
--  1) ControlUnit: control signals for each opcode (including unused opcodes).
--  2) ALUDecoder: table (ALUOp, funct3, funct7_5) -> ALUControl.
--  3) Full chain: 32-bit instruction -> ControlUnit -> ALUDecoder -> ALUControl,
--     with the real instructions of the program and those the ROM does not use
--     (andi, ori, xori, slti, slli, srli, slt).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_Control is
end tb_Control;

architecture sim of tb_Control is

    -- ControlUnit 
    signal Op        : std_logic_vector(6 downto 0) := (others => '0');
    signal Branch    : std_logic;
    signal ResultSrc : std_logic;
    signal MemWrite  : std_logic;
    signal ALUSrc    : std_logic;
    signal ImmSrc    : std_logic_vector(1 downto 0);
    signal RegWrite  : std_logic;
    signal ALUOp     : std_logic_vector(1 downto 0);

    
    signal d_ALUOp   : std_logic_vector(1 downto 0) := "00";
    signal d_f3      : std_logic_vector(2 downto 0) := "000";
    signal d_f7      : std_logic := '0';
    signal d_ctl     : std_logic_vector(2 downto 0);

    -- Decoder chained to the ControlUnit
    signal c_f3      : std_logic_vector(2 downto 0) := "000";
    signal c_f7      : std_logic := '0';
    signal c_ctl     : std_logic_vector(2 downto 0);

    function to_bits(v : std_logic_vector) return string is
        variable r : string(1 to v'length);
        variable k : integer := 1;
    begin
        for i in v'range loop
            if v(i) = '1' then r(k) := '1';
            elsif v(i) = '0' then r(k) := '0';
            else r(k) := 'X';
            end if;
            k := k + 1;
        end loop;
        return r;
    end function;

begin

    u_ctrl: entity work.ControlUnit
        port map (
            Op => Op, Branch => Branch, ResultSrc => ResultSrc,
            MemWrite => MemWrite, ALUSrc => ALUSrc, ImmSrc => ImmSrc,
            RegWrite => RegWrite, ALUOp => ALUOp
        );

    u_dec_direct: entity work.ALUDecoder
        port map (ALUOp => d_ALUOp, funct3 => d_f3, funct7_5 => d_f7, ALUControl => d_ctl);

    u_dec_chain: entity work.ALUDecoder
        port map (ALUOp => ALUOp, funct3 => c_f3, funct7_5 => c_f7, ALUControl => c_ctl);

    stim: process
        variable errors : integer := 0;
        variable tests  : integer := 0;

        procedure check(cond : in boolean; msg : in string) is
        begin
            tests := tests + 1;
            if cond then
                report "PASS: " & msg severity note;
            else
                errors := errors + 1;
                report "FAIL: " & msg severity error;
            end if;
        end procedure;

        
        procedure test_ctrl(opc  : in std_logic_vector(6 downto 0);
                            expr : in std_logic_vector(8 downto 0);
                            name : in string) is
            variable got : std_logic_vector(8 downto 0);
        begin
            Op <= opc;
            wait for 10 ns;
            got := Branch & ResultSrc & MemWrite & ALUSrc & ImmSrc & RegWrite & ALUOp;
            check(got = expr,
                  name & ": expected " & to_bits(expr) & " got " & to_bits(got));
        end procedure;

        procedure test_dec(aop  : in std_logic_vector(1 downto 0);
                           f3   : in std_logic_vector(2 downto 0);
                           f7   : in std_logic;
                           expr : in std_logic_vector(2 downto 0);
                           name : in string) is
        begin
            d_ALUOp <= aop; d_f3 <= f3; d_f7 <= f7;
            wait for 10 ns;
            check(d_ctl = expr,
                  name & ": expected " & to_bits(expr) & " got " & to_bits(d_ctl));
        end procedure;

        procedure test_instr(word : in std_logic_vector(31 downto 0);
                             expr : in std_logic_vector(2 downto 0);
                             name : in string) is
        begin
            Op   <= word(6 downto 0);
            c_f3 <= word(14 downto 12);
            c_f7 <= word(30);
            wait for 10 ns;
            check(c_ctl = expr,
                  name & ": ALUControl expected " & to_bits(expr) & " got " & to_bits(c_ctl));
        end procedure;

    begin
        -- 1) ControlUnit
        test_ctrl("0110011", "000000110", "C1 R-type");
        test_ctrl("0010011", "000100111", "C2 I-type (ALUOp = 11)");
        test_ctrl("0000011", "010100100", "C3 lw");
        test_ctrl("0100011", "001101000", "C4 sw");
        test_ctrl("1100011", "100010001", "C5 beq");
        test_ctrl("1110011", "000000000", "C6 mret/system opcode: no effect");
        test_ctrl("0000000", "000000000", "C7 null instruction: no effect");
        test_ctrl("1111111", "000000000", "C8 unimplemented opcode: no effect");

        -- 2) ALUDecoder (direct inputs)
        -- ALUOp 00: lw/sw -> ADD, regardless of funct3
        test_dec("00", "000", '0', "010", "D1 ALUOp 00 -> ADD");
        test_dec("00", "111", '1', "010", "D2 ALUOp 00 ignores funct3/funct7");
        -- ALUOp 01: beq -> SUB
        test_dec("01", "000", '0', "110", "D3 ALUOp 01 -> SUB");
        test_dec("01", "101", '1', "110", "D4 ALUOp 01 ignores funct3/funct7");
        -- ALUOp 10: R-type
        test_dec("10", "000", '0', "010", "D5 R add");
        test_dec("10", "000", '1', "110", "D6 R sub (funct7_5 = 1)");
        test_dec("10", "001", '0', "100", "D7 R sll");
        test_dec("10", "010", '0', "111", "D8 R slt");
        test_dec("10", "100", '0', "011", "D9 R xor");
        test_dec("10", "101", '0', "101", "D10 R srl");
        test_dec("10", "110", '0', "001", "D11 R or");
        test_dec("10", "111", '0', "000", "D12 R and");
        test_dec("10", "101", '1', "101", "D13 R funct3=101 with bit30: sra not implemented, behaves like srl");
        -- ALUOp 11: I-type
        test_dec("11", "000", '0', "010", "D14 I addi");
        test_dec("11", "000", '1', "010", "D15 I addi with negative immediate (bit30=1): stays ADD");
        test_dec("11", "001", '0', "100", "D16 I slli");
        test_dec("11", "010", '0', "111", "D17 I slti");
        test_dec("11", "100", '0', "011", "D18 I xori");
        test_dec("11", "101", '0', "101", "D19 I srli");
        test_dec("11", "110", '0', "001", "D20 I ori");
        test_dec("11", "111", '0', "000", "D21 I andi");

        -- 3) Instruction -> ALUControl chain
        test_instr(x"001181B3", "010", "I01 add x3,x3,x1");
        test_instr(x"401181B3", "110", "I02 sub x3,x3,x1");
        test_instr(x"0011F1B3", "000", "I03 and x3,x3,x1");
        test_instr(x"0011E1B3", "001", "I04 or  x3,x3,x1");
        test_instr(x"0011C1B3", "011", "I05 xor x3,x3,x1");
        test_instr(x"001191B3", "100", "I06 sll x3,x3,x1");
        test_instr(x"0011D1B3", "101", "I07 srl x3,x3,x1");
        test_instr(x"0011A1B3", "111", "I08 slt x3,x3,x1");
        test_instr(x"0070D333", "101", "I09 srl x6,x1,x7");
        test_instr(x"FFF28293", "010", "I10 addi x5,x5,-1");
        test_instr(x"00E00393", "010", "I11 addi x7,x0,14");
        test_instr(x"00219193", "100", "I12 slli x3,x3,2");
        test_instr(x"0021D193", "101", "I13 srli x3,x3,2");
        test_instr(x"0021A193", "111", "I14 slti x3,x3,2");
        test_instr(x"0021F193", "000", "I15 andi x3,x3,2");
        test_instr(x"0021E193", "001", "I16 ori  x3,x3,2");
        test_instr(x"0021C193", "011", "I17 xori x3,x3,2");
        test_instr(x"30002203", "010", "I18 lw x4,768(x0)");
        test_instr(x"20302023", "010", "I19 sw x3,512(x0)");
        test_instr(x"0A020063", "110", "I20 beq x4,x0,+160");

        report "Checks run: " & integer'image(tests) &
               ", failed: " & integer'image(errors) severity note;
        if errors = 0 then
            report "RESULT: ALL TESTS PASSED" severity note;
        else
            report "RESULT: " & integer'image(errors) & " TESTS FAILED" severity error;
        end if;
        wait;
    end process;

end sim;