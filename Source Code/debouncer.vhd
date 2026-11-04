library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
    Generic (
        LIMIT : integer := 1_000_000
    );
    Port ( 
        clk    : in  STD_LOGIC;
        reset  : in  STD_LOGIC;
        bouncy : in  STD_LOGIC;  -- Dirty signal of the button
        pulse  : out STD_LOGIC;   -- Clean signal just for one clock cycle
        button_state : out STD_LOGIC  -- State of the button
    );
end debouncer;

architecture Behavioral of debouncer is
    signal count : integer range 0 to LIMIT := 0;
    signal stable_value : std_logic := '0';
    signal candidate_value : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                count <= 0;
                stable_value <= '0';
                pulse <= '0';
            else
                pulse <= '0'; -- Default: no impulse
                
                --If the input signal changes 
                if bouncy /= candidate_value then
                    candidate_value <= bouncy; -- Move to the next signal
                    count <= 0;                -- Reset timer
                
                --If the signal is stable
                else
                    if count < LIMIT then
                        count <= count + 1; 
                    else
                        -- If we have reached the threshold then
                        if candidate_value /= stable_value then
                            stable_value <= candidate_value;
                            
                            -- we generate impulse, only if the button was pressed
                            if candidate_value = '1' then
                                pulse <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    button_state <= stable_value;

end Behavioral;