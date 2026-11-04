-- Self-checking unit test of the immediate generator:
-- I, S and B formats with positive, negative and limit values, plus the unused ImmSrc.
-- The instructions are 32-bit words; the DUT receives bits 31..7.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ImmGen is
end tb_ImmGen;

architecture sim of tb_ImmGen is

    signal Instr  : std_logic_vector(31 downto 7) := (others => '0');
    signal ImmSrc : std_logic_vector(1 downto 0)  := "00";
    signal ImmExt : std_logic_vector(31 downto 0);

    function to_hex(v : std_logic_vector(31 downto 0)) return string is
        constant HEX : string(1 to 16) := "0123456789ABCDEF";
        variable r   : string(1 to 8);
        variable n   : integer;
    begin
        for i in 0 to 7 loop
            n := to_integer(unsigned(v(31 - 4*i downto 28 - 4*i)));
            r(i + 1) := HEX(n + 1);
        end loop;
        return r;
    end function;

begin

    uut: entity work.ImmGen
        port map (Instr => Instr, ImmSrc => ImmSrc, ImmExt => ImmExt);

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

        procedure test(word : in std_logic_vector(31 downto 0);
                       src  : in std_logic_vector(1 downto 0);
                       expr : in std_logic_vector(31 downto 0);
                       name : in string) is
        begin
            Instr  <= word(31 downto 7);
            ImmSrc <= src;
            wait for 10 ns;
            check(ImmExt = expr,
                  name & " [" & to_hex(word) & "]: expected " & to_hex(expr) &
                  " got " & to_hex(ImmExt));
        end procedure;

    begin
        -- I type (ImmSrc = 00)
        test(x"00E00393", "00", x"0000000E", "I: addi x7,x0,14");
        test(x"FFF28293", "00", x"FFFFFFFF", "I: addi x5,x5,-1 (sign extension)");
        test(x"30002203", "00", x"00000300", "I: lw x4,768(x0)");
        test(x"80000013", "00", x"FFFFF800", "I: minimum -2048");
        test(x"7FF00013", "00", x"000007FF", "I: maximum 2047");

        -- S type (ImmSrc = 01)
        test(x"20302023", "01", x"00000200", "S: sw x3,512(x0)");
        test(x"003023A3", "01", x"00000007", "S: sw x3,7(x0) (low field imm[4:0])");
        test(x"FE302E23", "01", x"FFFFFFFC", "S: sw x3,-4(x0) (negative)");

        -- B type (ImmSrc = 10)
        test(x"0A020063", "10", x"000000A0", "B: beq x4,x0,+160 (jump to mret)");
        test(x"00000063", "10", x"00000000", "B: beq x0,x0,0 (idle loop)");
        test(x"02520063", "10", x"00000020", "B: beq x4,x5,+32");
        test(x"04000A63", "10", x"00000054", "B: beq x0,x0,+84 (field imm[4:1])");
        test(x"FE000EE3", "10", x"FFFFFFFC", "B: beq x0,x0,-4 (negative)");
        test(x"000000E3", "10", x"00000800", "B: imm[11] (bit 7 of the instruction)");
        test(x"80000063", "10", x"FFFFF000", "B: minimum -4096 (bit 31)");

        -- ImmSrc not used (11): output is zero
        test(x"FFFFFFFF", "11", x"00000000", "ImmSrc = 11: output is 0");

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