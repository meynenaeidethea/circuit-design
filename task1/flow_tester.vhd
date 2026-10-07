library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flow_tester is
    generic (STEP_CYCLES : positive := 5_000_000);
    port (
        clk_i     : in  std_logic;
        nRst_i    : in  std_logic;
        sensorA_o : out std_logic;
        sensorB_o : out std_logic;
        weight_o  : out std_logic_vector(7 downto 0)
    );
end flow_tester;

architecture rtl of flow_tester is
    signal stepCount_r : natural range 0 to STEP_CYCLES - 1;
    signal position_r  : natural range 0 to 15;
    signal rejectProduct_r : std_logic;
begin
    counter_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            stepCount_r <= 0;
            position_r  <= 0;
            rejectProduct_r <= '0';
        elsif rising_edge(clk_i) then
            if stepCount_r = STEP_CYCLES - 1 then
                stepCount_r <= 0;
                if position_r = 15 then
                    position_r <= 0;
                    rejectProduct_r <= not rejectProduct_r;
                else
                    position_r <= position_r + 1;
                end if;
            else
                stepCount_r <= stepCount_r + 1;
            end if;
        end if;
    end process;

    output_logic : process(all)
        variable peakWeight_v : natural range 80 to 100;
    begin
        -- Start with a valid product; alternate profiles after each 16-step cycle.
        if rejectProduct_r = '1' then
            peakWeight_v := 80;
        else
            peakWeight_v := 100;
        end if;
        sensorA_o <= '0';
        sensorB_o <= '0';
        weight_o  <= (others => '0');
        case position_r is
            when 2 => sensorA_o <= '1'; weight_o <= std_logic_vector(to_unsigned(20, weight_o'length));
            when 3 => sensorA_o <= '1'; weight_o <= std_logic_vector(to_unsigned(peakWeight_v - 50, weight_o'length));
            when 4 => sensorA_o <= '1'; sensorB_o <= '1'; weight_o <= std_logic_vector(to_unsigned(peakWeight_v - 20, weight_o'length));
            when 5 => sensorA_o <= '1'; sensorB_o <= '1'; weight_o <= std_logic_vector(to_unsigned(peakWeight_v, weight_o'length));
            when 6 => sensorA_o <= '1'; sensorB_o <= '1'; weight_o <= std_logic_vector(to_unsigned(peakWeight_v - 2, weight_o'length));
            when 7 => sensorB_o <= '1'; weight_o <= std_logic_vector(to_unsigned(peakWeight_v - 30, weight_o'length));
            when 8 => sensorB_o <= '1'; weight_o <= std_logic_vector(to_unsigned(30, weight_o'length));
            when others => null;
        end case;
    end process;
end rtl;
