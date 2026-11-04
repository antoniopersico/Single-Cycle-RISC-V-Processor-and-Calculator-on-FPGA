-- Self-checking testbench for the RISC-V core running the calculator ISR.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_Core is
end tb_Core;

architecture sim of tb_Core is

    constant T_CLK      : time := 20 ns;                       -- 50 MHz
    constant RANDOM_VAL : std_logic_vector(15 downto 0) := x"A5C3";

    -- Signals to the core
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';                       
    signal irq       : std_logic := '0';
    signal ReadData  : std_logic_vector(31 downto 0);
    signal ALUResult : std_logic_vector(31 downto 0);
    signal WriteData : std_logic_vector(31 downto 0);
    signal MemWrite  : std_logic;

    -- Simulated peripherals
    signal sw_val    : std_logic_vector(15 downto 0) := (others => '0');
    signal btn_val   : std_logic_vector(4 downto 0)  := (others => '0');
    signal display   : std_logic_vector(31 downto 0) := (others => '0');
    signal wr_count  : integer := 0;                           -- writes to 0x200

    signal sim_done  : boolean := false;

    -- Conversion to a hexadecimal string
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

    -- Reference model of the ISR
    function model(acc : unsigned(31 downto 0);
                   btn : std_logic_vector(4 downto 0);
                   sw  : std_logic_vector(15 downto 0)) return unsigned is
        variable x1   : unsigned(31 downto 0);
        variable sh   : integer range 0 to 31;
        variable mode : integer range 0 to 3;
        variable res  : unsigned(31 downto 0);
    begin
        x1   := resize(unsigned(sw(13 downto 0)), 32);         -- mask
        sh   := to_integer(x1(4 downto 0));                    -- only the 5 low bits count
        mode := to_integer(unsigned(sw(15 downto 14)));
        res  := acc;
        case btn is
            when "00000" => res := acc;                        
            when "00001" => res := acc and x1;                 
            when "00010" => res := acc or x1;                  
            when "00100" => res := acc - x1;                   
            when "01000" => res := acc + x1;                   
            when others  =>                                    
                case mode is
                    when 0      => res := acc xor x1;
                    when 1      => res := shift_right(acc, sh);
                    when 2      => res := shift_left(acc, sh);
                    when others => res := resize(unsigned(RANDOM_VAL), 32);
                end case;
        end case;
        return res;
    end function;

begin

    -- DUT
    uut: entity work.RISCV_Core
        port map (
            clk       => clk,
            reset     => reset,
            irq       => irq,
            ReadData  => ReadData,
            ALUResult => ALUResult,
            WriteData => WriteData,
            MemWrite  => MemWrite
        );

    -- Clock 
    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

    -- Simulated peripherals
    ReadData <= x"0000" & sw_val                 when ALUResult = x"00000100" else
                x"000000" & "000" & btn_val      when ALUResult = x"00000300" else
                x"0000" & RANDOM_VAL             when ALUResult = x"00000400" else
                (others => '0');

    -- Simulated display
    display_proc: process(clk)
    begin
        if rising_edge(clk) then
            if MemWrite = '1' and ALUResult = x"00000200" then
                display  <= WriteData;
                wr_count <= wr_count + 1;
            end if;
        end if;
    end process;

    -- Stimuli and checks
    stim: process
        variable acc      : unsigned(31 downto 0) := (others => '0');  -- copy of x3
        variable errors   : integer := 0;
        variable tests    : integer := 0;
        variable rst_base : integer := 0;
        variable cnt0     : integer := 0;

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

        -- One-clock-cycle irq pulse 
        procedure fire_irq is
        begin
            wait until falling_edge(clk);
            irq <= '1';
            wait until rising_edge(clk);
            irq <= '0';
        end procedure;

        -- Reset 
        procedure apply_reset is
        begin
            reset <= '0';
            tick(3);
            wait until falling_edge(clk);
            rst_base := wr_count;
            reset <= '1';
            tick(10);
            acc := (others => '0');
        end procedure;

        procedure press(b    : in std_logic_vector(4 downto 0);
                        s    : in std_logic_vector(15 downto 0);
                        name : in string) is
            variable exp_acc : unsigned(31 downto 0);
        begin
            sw_val  <= s;
            btn_val <= b;
            tick(1);
            cnt0 := wr_count;
            fire_irq;
            tick(40);
            exp_acc := model(acc, b, s);
            if b = "00000" then
                check(wr_count = cnt0,
                      name & ": no write to the display");
            else
                check(wr_count = cnt0 + 1,
                      name & ": exactly one write to the display");
            end if;
            check(display = std_logic_vector(exp_acc),
                  name & ": expected " & to_hex(std_logic_vector(exp_acc)) &
                  " got " & to_hex(display));
            acc     := exp_acc;
            btn_val <= (others => '0');
            tick(2);
        end procedure;

    begin
    
        -- T01: reset and main program
        apply_reset;
        check(display = x"00000000", "T01 main: display = 0 after reset");
        check(wr_count - rst_base = 1, "T01 main: a single write (sw x3) after reset");
        -- Direction buttons
        press("01000", x"0005", "T02 ADD 0+5");
        press("00010", x"000A", "T03 OR  5|A");
        press("00001", x"0006", "T04 AND F&6");
        press("00100", x"0003", "T05 SUB 6-3");
        press("00100", x"0005", "T06 SUB negative result 3-5");
        press("00001", x"C00F", "T07 AND, mode bits ignored");
        press("01000", x"0001", "T08 ADD +1");
        -- Center button
        press("10000", x"0003", "T09 XOR (mode 0)");
        press("10000", x"4001", "T10 SRL by 1 (mode 1)");
        press("10000", x"8003", "T11 SLL by 3 (mode 2)");
        press("10000", x"8021", "T12 SLL, amount 33 -> only 33 mod 32 = 1 counts");
        press("00100", x"0060", "T13 SUB to bring x3 back to 1");
        press("10000", x"801F", "T14 SLL by 31");
        press("10000", x"4004", "T15 SRL by 4 on 0x80000000 (logical shift)");
        press("10000", x"8000", "T16 SLL by 0 (unchanged)");
        press("10000", x"C000", "T17 RANDOM (mode 3)");
        -- Corner cases on the buttons
        press("00011", x"0002", "T18 two buttons together -> center-button logic");
        press("00000", x"0005", "T19 release (x4 = 0): jumps to mret, no write");
        press("01000", x"0001", "T20 the ISR still works after a release");

        -- T21: second irq while the ISR is running
        apply_reset;
        sw_val  <= x"0005";
        btn_val <= "01000";
        tick(1);
        cnt0 := wr_count;
        fire_irq;
        tick(12);                       -- we are inside the ISR
        fire_irq;                       -- second irq: must be ignored
        tick(40);
        check(display = x"00000005",
              "T21 nested irq ignored: ADD executed only once, got " & to_hex(display));
        check(wr_count = cnt0 + 1, "T21 nested irq: a single write to the display");
        acc     := to_unsigned(5, 32);
        btn_val <= (others => '0');
        tick(2);

        -- T22: irq in the same cycle as the sw of the main (PC = 4)
        --      the interrupted instruction must have no effect and be executed again
        sw_val  <= x"0005";
        btn_val <= "01000";
        reset   <= '0';
        tick(3);
        wait until falling_edge(clk);
        rst_base := wr_count;
        reset <= '1';
        wait until rising_edge(clk);    -- PC: 0 -> 4
        wait until falling_edge(clk);   -- cycle with PC = 4 (sw x3, 512(x0))
        irq <= '1';
        wait until rising_edge(clk);    -- irq_take: the sw is cancelled
        irq <= '0';
        tick(60);
        check(wr_count - rst_base = 2,
              "T22 interrupted sw: 2 writes (ISR + replayed sw), found " &
              integer'image(wr_count - rst_base));
        check(display = x"00000005", "T22 display = 5, got " & to_hex(display));
        acc     := to_unsigned(5, 32);
        btn_val <= (others => '0');
        tick(2);

        -- T23: reset in the middle of the ISR
        sw_val  <= x"0003";
        btn_val <= "01000";
        tick(1);
        fire_irq;
        tick(8);                        -- inside the ISR
        apply_reset;
        check(display = x"00000000", "T23 after reset the main restarts and writes 0");
        press("01000", x"0007", "T23 irq after a reset during the ISR (in_isr cleared)");

        -- Summary
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