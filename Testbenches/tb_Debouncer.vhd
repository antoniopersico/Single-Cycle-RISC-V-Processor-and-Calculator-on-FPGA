-- Self-checking unit test for the debouncer, with CLK_LIMIT reduced to 10 cycles
-- (the real value is 1,000,000 = 20 ms at 50 MHz; the logic is identical).
--   - single, one-cycle pulse after a stable press
--   - no pulse for bounces or presses shorter than the limit
--   - no pulse on release
--   - two consecutive presses -> two pulses
--   - reset

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_Debouncer is
end tb_Debouncer;

architecture sim of tb_Debouncer is

    constant T_CLK : time    := 20 ns;
    constant L     : integer := 10;          -- CLK_LIMIT of the test

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';  -- active low, synchronous
    signal bouncy       : std_logic := '0';
    signal pulse        : std_logic;
    signal button_state : std_logic;
    signal pulse_count  : integer := 0;      -- clock cycles with pulse = 1
    signal sim_done     : boolean := false;

begin

    uut: entity work.debouncer
        generic map (CLK_LIMIT => L)
        port map (
            clk          => clk,
            reset        => reset,
            bouncy       => bouncy,
            pulse        => pulse,
            button_state => button_state
        );

    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

    -- Counts the cycles in which pulse is high: a 1-cycle pulse increments by 1
    mon: process(clk)
    begin
        if rising_edge(clk) then
            if pulse = '1' then
                pulse_count <= pulse_count + 1;
            end if;
        end if;
    end process;

    stim: process
        variable errors : integer := 0;
        variable tests  : integer := 0;
        variable n0     : integer;
        variable k      : integer;
        variable found  : boolean;

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

        -- Sets the input right after an edge and holds it for n cycles
        procedure hold(v : in std_logic; n : in integer) is
        begin
            bouncy <= v;
            tick(n);
        end procedure;

        -- Number of pulse cycles seen so far (with 1 ns margin after the edge)
        procedure snap(variable n : out integer) is
        begin
            wait for 1 ns;
            n := pulse_count;
        end procedure;

    begin
        -- Initial reset
        reset <= '0';
        tick(3);
        reset <= '1';
        tick(2);
        wait for 1 ns;
        check(pulse = '0' and button_state = '0', "B01 initial state: no pulse, button at 0");

        -- B02: stable press -> a single one-cycle pulse
        snap(n0);
        bouncy <= '1';
        found := false;
        k := 0;
        for i in 1 to L + 10 loop
            wait until rising_edge(clk);
            if pulse = '1' and not found then
                found := true;
                k := i;
            end if;
        end loop;
        check(found and k > L and k <= L + 5,
              "B02 pulse after the stability time (cycles: " & integer'image(k) & ")");
        wait for 1 ns;
        check(pulse_count - n0 = 1,
              "B02 a single one-cycle pulse, counted " & integer'image(pulse_count - n0));
        check(button_state = '1', "B02 button_state = 1 while pressed");

        -- B03: holding the button does not generate further pulses
        snap(n0);
        tick(3 * L);
        wait for 1 ns;
        check(pulse_count = n0, "B03 no new pulse while the button stays pressed");
        check(button_state = '1', "B03 button_state stays at 1");

        -- B04: stable release -> no pulse, state at 0
        snap(n0);
        hold('0', 3 * L);
        wait for 1 ns;
        check(pulse_count = n0, "B04 no pulse on release");
        check(button_state = '0', "B04 button_state returns to 0 after the stable release");

        -- B05: bounces only (all shorter than L) -> no pulse
        snap(n0);
        hold('1', 3);
        hold('0', 2);
        hold('1', 4);
        hold('0', 3);
        hold('1', 2);
        hold('0', 2 * L);
        wait for 1 ns;
        check(pulse_count = n0, "B05 short bounces: no pulse");
        check(button_state = '0', "B05 short bounces: button_state stays at 0");

        -- B06: press shorter than the limit -> no pulse
        snap(n0);
        hold('1', L - 3);
        hold('0', 2 * L);
        wait for 1 ns;
        check(pulse_count = n0, "B06 short press (fewer than L cycles): no pulse");
        check(button_state = '0', "B06 short press: button_state stays at 0");

        -- B07: bounces followed by a stable press -> a single pulse,
        --      and the timer restarts from the last bounce
        snap(n0);
        hold('1', 3);
        hold('0', 2);
        bouncy <= '1';
        tick(L - 2);
        wait for 1 ns;
        check(pulse_count = n0, "B07 before the stability time there is no pulse yet");
        tick(L + 10);
        wait for 1 ns;
        check(pulse_count - n0 = 1, "B07 after the bounces, a stable press generates a single pulse");
        check(button_state = '1', "B07 button_state = 1");
        hold('0', 3 * L);

        -- B08: two consecutive presses -> two pulses
        snap(n0);
        hold('1', 3 * L);
        hold('0', 3 * L);
        hold('1', 3 * L);
        wait for 1 ns;
        check(pulse_count - n0 = 2, "B08 two distinct presses: two pulses, counted " &
                                    integer'image(pulse_count - n0));
        hold('0', 3 * L);

        -- B09: reset with the button held down
        --      (the stable state is cleared; still pressed -> new pulse after stabilization)
        hold('1', 3 * L);
        check(button_state = '1', "B09 before the reset button_state = 1");
        reset <= '0';
        tick(3);
        wait for 1 ns;
        check(button_state = '0' and pulse = '0', "B09 during the reset state and pulse are cleared");
        snap(n0);
        reset <= '1';
        tick(3 * L);
        wait for 1 ns;
        check(pulse_count - n0 = 1, "B09 button still pressed after the reset: one new pulse");
        hold('0', 3 * L);

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