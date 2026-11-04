library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_RISCV_Core is
-- Nessuna porta necessaria per un testbench
end tb_RISCV_Core;

architecture Behavioral of tb_RISCV_Core is

    component RISCV_Core
        Port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC
        );
    end component;

    signal clk_tb   : STD_LOGIC := '0';
    signal reset_tb : STD_LOGIC := '1'; -- Partiamo con il sistema in reset (bloccato)

    constant clk_period : time := 10 ns;

begin

    -- Istanziazione della CPU completa
    uut: RISCV_Core port map (
        clk   => clk_tb,
        reset => reset_tb
    );

    -- Generazione continua del Clock
    clk_process: process
    begin
        clk_tb <= '0';
        wait for clk_period/2;
        clk_tb <= '1';
        wait for clk_period/2;
    end process;

    -- Stimoli: Gestione del Reset
    stim_proc: process
    begin
        -- Teniamo il reset alto per un paio di cicli di clock per stabilizzare il sistema
        wait for 20 ns;
        
        -- Rilasciamo il reset: il PC andrà a 0 e la CPU inizierà a leggere e calcolare
        reset_tb <= '0';

        -- Lasciamo scorrere la simulazione abbastanza a lungo per eseguire le tre istruzioni
        wait for 100 ns;
        
        -- Mette in pausa il testbench
        wait;
    end process;

end Behavioral;