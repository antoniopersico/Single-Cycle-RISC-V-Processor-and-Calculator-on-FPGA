-- Self-checking unit test for the MMIO_Decoder:
--   read of switches (0x100), buttons (0x300), random (0x400) and RAM (other addresses),
--   write to the display only at 0x200, DataMem_WE only below 0xFF, reset.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_MMIO is
end tb_MMIO;

architecture sim of tb_MMIO is

    constant T_CLK : time := 20 ns;

    signal clk              : std_logic := '0';
    signal reset            : std_logic := '0';                 -- active low
    signal Address          : std_logic_vector(31 downto 0) := (others => '0');
    signal WriteData        : std_logic_vector(31 downto 0) := (others => '0');
    signal MemWrite         : std_logic := '0';
    signal ReadData         : std_logic_vector(31 downto 0);
    signal DataMem_ReadData : std_logic_vector(31 downto 0) := x"CAFEBABE";
    signal DataMem_WE       : std_logic;
    signal Switches         : std_logic_vector(15 downto 0) := (others => '0');
    signal Buttons          : std_logic_vector(4 downto 0)  := (others => '0');
    signal Seg_Data         : std_logic_vector(31 downto 0);
    signal sim_done         : boolean := false;

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

    uut: entity work.MMIO_Decoder
        port map (
            clk              => clk,
            reset            => reset,
            Address          => Address,
            WriteData        => WriteData,
            MemWrite         => MemWrite,
            ReadData         => ReadData,
            DataMem_ReadData => DataMem_ReadData,
            DataMem_WE       => DataMem_WE,
            Switches         => Switches,
            Buttons          => Buttons,
            Seg_Data         => Seg_Data
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
        variable r1, r2 : integer;

        procedure tick(n : in integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

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

        -- CPU write: a single rising edge with MemWrite = en
        procedure write_at(addr : in std_logic_vector(31 downto 0);
                           data : in std_logic_vector(31 downto 0);
                           en   : in std_logic) is
        begin
            wait until falling_edge(clk);
            Address   <= addr;
            WriteData <= data;
            MemWrite  <= en;
            wait until rising_edge(clk);
            MemWrite  <= '0';
            wait for 1 ns;
        end procedure;

        procedure read_chk(addr : in std_logic_vector(31 downto 0);
                           expr : in std_logic_vector(31 downto 0);
                           name : in string) is
        begin
            Address <= addr;
            wait for 5 ns;
            check(ReadData = expr,
                  name & ": expected " & to_hex(expr) & " got " & to_hex(ReadData));
        end procedure;

        -- DataMem_WE check away from clock edges (no side effects)
        procedure we_chk(addr : in std_logic_vector(31 downto 0);
                         mw   : in std_logic;
                         expr : in std_logic;
                         name : in string) is
        begin
            wait until falling_edge(clk);
            Address  <= addr;
            MemWrite <= mw;
            wait for 5 ns;
            check(DataMem_WE = expr, name);
            MemWrite <= '0';
        end procedure;

    begin
        -- M01: reset
        reset <= '0';
        tick(3);
        wait for 1 ns;
        check(Seg_Data = x"00000000", "M01 reset: display at 0");

        -- Release reset at mid-cycle, then 4 edges: the random counter equals 4
        Address <= x"00000400";
        wait until falling_edge(clk);
        reset <= '1';
        tick(4);
        wait for 1 ns;
        check(ReadData = x"00000004",
              "M02 random: 4 edges after reset it equals 4, got " & to_hex(ReadData));

        -- M03: the counter advances by 1 on every clock
        r1 := to_integer(unsigned(ReadData(15 downto 0)));
        tick(5);
        wait for 1 ns;
        r2 := to_integer(unsigned(ReadData(15 downto 0)));
        check(r2 - r1 = 5, "M03 random: +5 after 5 edges, difference " & integer'image(r2 - r1));
        check(ReadData(31 downto 16) = x"0000", "M03 random: the upper 16 bits are 0");

        -- Reads from peripherals (the RAM presents CAFEBABE: it must not pass through)
        Switches <= x"A5F3";
        read_chk(x"00000100", x"0000A5F3", "M04 switch read at 0x100");
        Buttons  <= "10101";
        read_chk(x"00000300", x"00000015", "M05 button read at 0x300");

        -- Reads from RAM and from non-peripheral addresses
        read_chk(x"00000010", x"CAFEBABE", "M06 RAM read at 0x10");
        read_chk(x"000000FC", x"CAFEBABE", "M07 RAM read at 0xFC");
        read_chk(x"00000200", x"CAFEBABE", "M08 0x200 is not readable: RAM data passes through");

        -- Write to the display
        write_at(x"00000200", x"DEADBEEF", '1');
        check(Seg_Data = x"DEADBEEF", "M09 write at 0x200: display = DEADBEEF");
        tick(3);
        wait for 1 ns;
        check(Seg_Data = x"DEADBEEF", "M10 display holds its value");

        -- Writes that must NOT touch the display
        write_at(x"00000200", x"11111111", '0');
        check(Seg_Data = x"DEADBEEF", "M11 0x200 with MemWrite = 0: display unchanged");
        write_at(x"00000010", x"22222222", '1');
        check(Seg_Data = x"DEADBEEF", "M12 write to RAM (0x10): display unchanged");
        write_at(x"00000100", x"33333333", '1');
        check(Seg_Data = x"DEADBEEF", "M13 write at 0x100 (switches): display unchanged");
        write_at(x"00000300", x"44444444", '1');
        check(Seg_Data = x"DEADBEEF", "M14 write at 0x300 (buttons): display unchanged");
        write_at(x"00000400", x"55555555", '1');
        check(Seg_Data = x"DEADBEEF", "M15 write at 0x400 (random): display unchanged");

        -- Display update
        write_at(x"00000200", x"0000002A", '1');
        check(Seg_Data = x"0000002A", "M16 second write: display = 2A");

        -- DataMem_WE
        we_chk(x"00000000", '1', '1', "M17 WE=1 at 0x00 with MemWrite");
        we_chk(x"00000010", '1', '1', "M18 WE=1 at 0x10 with MemWrite");
        we_chk(x"000000FC", '1', '1', "M19 WE=1 at 0xFC (last RAM word)");
        we_chk(x"000000FF", '1', '0', "M20 WE=0 at 0xFF");
        we_chk(x"00000100", '1', '0', "M21 WE=0 at 0x100 (switches)");
        we_chk(x"00000200", '1', '0', "M22 WE=0 at 0x200 (display)");
        we_chk(x"00000300", '1', '0', "M23 WE=0 at 0x300 (buttons)");
        we_chk(x"00000400", '1', '0', "M24 WE=0 at 0x400 (random)");
        we_chk(x"00000010", '0', '0', "M25 WE=0 without MemWrite");

        -- Reset: the display is cleared (asynchronous)
        wait until falling_edge(clk);
        reset <= '0';
        wait for 2 ns;
        check(Seg_Data = x"00000000", "M26 reset: display cleared");
        tick(2);
        reset <= '1';
        tick(2);

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