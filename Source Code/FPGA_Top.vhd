-- Top level for the Nexys: connects the RISC-V core, the MMIO decoder, the data RAM,
-- the button debouncers and the 7-segment driver. The 50 MHz system clock is generated from
-- the 100 MHz board clock by an MMCM (Clocking Wizard IP, clk_wiz_0).
-- Data: CPU <-> MMIO_Decoder <-> RAM, switches, buttons, random counter, display register.
-- Interrupt: every confirmed button press (debouncer pulse) raises irq for one clock cycle.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FPGA_Top is
    Port (
        clk        : in  STD_LOGIC;                      
        reset_btn  : in  STD_LOGIC;                      -- CPU RESET button
        switches   : in  STD_LOGIC_VECTOR(15 downto 0);  -- sw[13:0] operand, sw[15:14] mode
        btnU       : in  STD_LOGIC;                      -- direction buttons
        btnD       : in  STD_LOGIC;
        btnL       : in  STD_LOGIC;
        btnR       : in  STD_LOGIC;
        btnC       : in  STD_LOGIC;                      -- center button
        seg_an     : out STD_LOGIC_VECTOR(7 downto 0);   -- 7-segment anodes
        seg_cat    : out STD_LOGIC_VECTOR(7 downto 0)    -- 7-segment cathodes 
    );
end FPGA_Top;

architecture Structural of FPGA_Top is

    -- Bus between the CPU, the MMIO decoder and the RAM
    signal cpu_address, cpu_writedata, cpu_readdata : STD_LOGIC_VECTOR(31 downto 0);
    signal cpu_memwrite                             : STD_LOGIC;
    signal ram_readdata                             : STD_LOGIC_VECTOR(31 downto 0);
    signal ram_we                                   : STD_LOGIC;

    -- Display
    signal display_data                             : STD_LOGIC_VECTOR(31 downto 0);

    -- Buttons: the four direction buttons are handled as a vector
    signal btn_bouncy                               : STD_LOGIC_VECTOR(3 downto 0);  -- raw inputs
    signal btn_clean                                : STD_LOGIC_VECTOR(3 downto 0);  -- debounced levels
    signal btn_pulse                                : STD_LOGIC_VECTOR(3 downto 0);  -- one-cycle press pulses
    signal btnC_clean                               : STD_LOGIC;
    signal btnC_pulse                               : STD_LOGIC;
    signal irq_sig                                  : STD_LOGIC;

    -- Clock
    signal clk_50                                   : STD_LOGIC;

    -- Clocking Wizard IP: 100 MHz in, 50 MHz out
    component clk_wiz_0
        port (
            clk_in1  : in  STD_LOGIC;
            clk_out1 : out STD_LOGIC;
            locked   : out STD_LOGIC
            );
    end component;
    
begin

    -- System clock. 
    u_clk: clk_wiz_0
        port map (clk_in1 => clk, clk_out1 => clk_50, locked => open);
    
    -- Group the direction buttons in a vector (index 3 = up, 2 = down, 1 = left, 0 = right)
    btn_bouncy <= btnU & btnD & btnL & btnR;

    -- One debouncer per direction button
    gen_debouncers: for i in 0 to 3 generate
        u_deb: entity work.debouncer
            port map (
                clk          => clk_50,
                reset        => reset_btn,
                bouncy       => btn_bouncy(i),
                pulse        => btn_pulse(i),
                button_state => btn_clean(i)
            );
    end generate;

    -- Debouncer of the center button
    u_deb_center: entity work.debouncer
        port map (
            clk          => clk_50,
            reset        => reset_btn,
            bouncy       => btnC,        
            pulse        => btnC_pulse,
            button_state => btnC_clean   
        );
        
    -- Interrupt request
    irq_sig <= btn_pulse(0) or btn_pulse(1) or btn_pulse(2) or btn_pulse(3) or btnC_pulse;

    -- RISC-V core
    u_CPU: entity work.RISCV_Core
        port map (
            clk       => clk_50,
            reset     => reset_btn,
            irq       => irq_sig,
            ReadData  => cpu_readdata,
            ALUResult => cpu_address,
            WriteData => cpu_writedata,
            MemWrite  => cpu_memwrite
        );

    -- MMIO decoder: routes the CPU loads and stores to the RAM or to the peripherals
    u_MMIO: entity work.MMIO_Decoder
        port map (
            clk              => clk_50,
            reset            => reset_btn,
            Address          => cpu_address,
            WriteData        => cpu_writedata,
            MemWrite         => cpu_memwrite,
            ReadData         => cpu_readdata,
            DataMem_ReadData => ram_readdata,
            DataMem_WE       => ram_we,
            Switches         => switches,
            -- Button states read by the ISR: bit 4 = center, 3 = up, 2 = down, 1 = left, 0 = right
            Buttons          => btnC_clean & btn_clean,
            Seg_Data         => display_data
        );

    -- Data RAM
    u_RAM: entity work.DataMemory
        port map (
            clk => clk_50,
            we  => ram_we,
            address   => cpu_address,
            wd  => cpu_writedata,
            rd  => ram_readdata
        );

    -- 7-segment display driver
    u_Display: entity work.seven_segment_driver
    generic map ( size => 20 )
    port map (
        clk     => clk_50,
        reset   => reset_btn,
        data_in => display_data,
        CA => seg_cat(0), CB => seg_cat(1), CC => seg_cat(2), CD => seg_cat(3),
        CE => seg_cat(4), CF => seg_cat(5), CG => seg_cat(6), DP => seg_cat(7),
        AN => seg_an
    );
end Structural;