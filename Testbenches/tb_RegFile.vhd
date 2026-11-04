-- Self-checking unit test for the register file (entity RegisterFile):
-- x0 always 0, write only with we3 = 1, dual read, asynchronous read,
-- synchronous write on the rising edge, sweep over all 31 registers.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_RegFile is
end tb_RegFile;

architecture sim of tb_RegFile is

    constant T_CLK : time := 20 ns;

    signal clk      : std_logic := '0';
    signal we3      : std_logic := '0';
    signal a1, a2   : std_logic_vector(4 downto 0) := (others => '0');
    signal a3       : std_logic_vector(4 downto 0) := (others => '0');
    signal wd3      : std_logic_vector(31 downto 0) := (others => '0');
    signal rd1, rd2 : std_logic_vector(31 downto 0);
    signal sim_done : boolean := false;

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

    function reg5(n : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(n, 5));
    end function;

    -- Reference value written to register i during the sweep
    function pattern(i : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(i * 16#01010101#, 32));
    end function;

begin

    uut: entity work.RegisterFile
        port map (
            clk => clk, we3 => we3,
            rs1 => a1, rs2 => a2, rd => a3,
            wd3 => wd3, rd1 => rd1, rd2 => rd2
        );

    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

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

        -- Write: data and address at mid-cycle, we3 high for one rising edge
        procedure write_reg(n : in integer; val : in std_logic_vector(31 downto 0);
                            en : in std_logic) is
        begin
            wait until falling_edge(clk);
            a3  <= reg5(n);
            wd3 <= val;
            we3 <= en;
            wait until rising_edge(clk);
            we3 <= '0';
        end procedure;

        -- Combinational read on both ports
        procedure read_check(r1 : in integer; r2 : in integer;
                             e1 : in std_logic_vector(31 downto 0);
                             e2 : in std_logic_vector(31 downto 0);
                             name : in string) is
        begin
            a1 <= reg5(r1);
            a2 <= reg5(r2);
            wait for 5 ns;
            check(rd1 = e1, name & " port 1 (x" & integer'image(r1) & "): expected " &
                            to_hex(e1) & " got " & to_hex(rd1));
            check(rd2 = e2, name & " port 2 (x" & integer'image(r2) & "): expected " &
                            to_hex(e2) & " got " & to_hex(rd2));
        end procedure;

    begin
        wait for 5 ns;

        -- R01: initial state
        read_check(1, 31, x"00000000", x"00000000", "R01 registers initially 0");

        -- R02: write and dual read
        write_reg(1, x"11111111", '1');
        write_reg(2, x"22222222", '1');
        read_check(1, 2, x"11111111", x"22222222", "R02 simultaneous read of two registers");
        read_check(2, 1, x"22222222", x"11111111", "R02 swapped ports");
        read_check(2, 2, x"22222222", x"22222222", "R02 same register on both ports");

        -- R03: x0 cannot be written and always reads 0
        write_reg(0, x"FFFFFFFF", '1');
        read_check(0, 0, x"00000000", x"00000000", "R03 x0 stays 0 after a write");

        -- R04: we3 = 0 -> no write
        write_reg(5, x"DEADBEEF", '0');
        read_check(5, 5, x"00000000", x"00000000", "R04 without we3 the register does not change");

        -- R05: overwrite
        write_reg(1, x"AAAAAAAA", '1');
        read_check(1, 2, x"AAAAAAAA", x"22222222", "R05 overwrite of x1, x2 intact");

        -- R06: asynchronous read and synchronous write on the edge
        write_reg(7, x"0000000A", '1');
        wait until falling_edge(clk);
        a1  <= reg5(7);
        a3  <= reg5(7);
        wd3 <= x"0000000B";
        we3 <= '1';
        wait for 5 ns;                  -- before the edge
        check(rd1 = x"0000000A", "R06 before the edge rd1 still shows the old value, got " & to_hex(rd1));
        wait until rising_edge(clk);
        we3 <= '0';
        wait for 5 ns;
        check(rd1 = x"0000000B", "R06 after the edge rd1 shows the new value, got " & to_hex(rd1));

        -- R07: sweep over all registers
        for i in 1 to 31 loop
            write_reg(i, pattern(i), '1');
        end loop;
        for i in 0 to 31 loop
            a1 <= reg5(i);
            a2 <= reg5(31 - i);
            wait for 5 ns;
            tests := tests + 2;
            if i = 0 then
                if rd1 /= x"00000000" then
                    errors := errors + 1;
                    report "FAIL R07: x0 must read 0, got " & to_hex(rd1) severity error;
                end if;
            elsif rd1 /= pattern(i) then
                errors := errors + 1;
                report "FAIL R07: x" & integer'image(i) & " expected " & to_hex(pattern(i)) &
                       " got " & to_hex(rd1) severity error;
            end if;
            if (31 - i) = 0 then
                if rd2 /= x"00000000" then
                    errors := errors + 1;
                    report "FAIL R07: x0 (port 2) must read 0, got " & to_hex(rd2) severity error;
                end if;
            elsif rd2 /= pattern(31 - i) then
                errors := errors + 1;
                report "FAIL R07: x" & integer'image(31 - i) & " (port 2) expected " &
                       to_hex(pattern(31 - i)) & " got " & to_hex(rd2) severity error;
            end if;
        end loop;
        report "R07 sweep of all registers finished" severity note;

        report "Checks run: " & integer'image(tests) &
               ", failed: " & integer'image(errors) severity note;
        if errors = 0 then
            report "RESULT: ALL TESTS PASSED" severity note;
        else
            report "RESULT: " & integer'image(errors) & " TESTS FAILED" severity error;
        end if;

        sim_done <= true;
        wait;
    end process;

end sim;