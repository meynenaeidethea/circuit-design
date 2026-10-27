library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

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
    signal stepCount_r : natural range 0 to STEP_CYCLES - 1 := STEP_CYCLES - 1;
    -- Countdown 15..0 corresponds to logical profile positions 0..15.
    signal position_r : natural range 0 to 15 := 15;
    signal rejectProduct_r : std_logic;
begin
    counter_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            stepCount_r <= STEP_CYCLES - 1;
            position_r <= 15;
            rejectProduct_r <= '0';
        elsif rising_edge(clk_i) then
            if stepCount_r = 0 then
                stepCount_r <= STEP_CYCLES - 1;
            else
                stepCount_r <= stepCount_r - 1;
            end if;

            if stepCount_r = 0 then
                if position_r = 0 then
                    position_r <= 15;
                    rejectProduct_r <= not rejectProduct_r;
                else
                    position_r <= position_r - 1;
                end if;
            end if;
        end if;
    end process;

    output_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            sensorA_o <= '0';
            sensorB_o <= '0';
            weight_o <= x"00";
        elsif rising_edge(clk_i) then
            if stepCount_r = 0 then
                -- Decode the position being entered on this same edge.
                -- Old countdown 14 means the next logical position is 2.
                if position_r >= 10 and position_r <= 14 then
                    sensorA_o <= '1';
                else
                    sensorA_o <= '0';
                end if;

                if position_r >= 8 and position_r <= 12 then
                    sensorB_o <= '1';
                else
                    sensorB_o <= '0';
                end if;

                if position_r = 14 then
                    weight_o <= x"14"; -- 20
                elsif position_r = 13 and rejectProduct_r = '0' then
                    weight_o <= x"32"; -- 50
                elsif position_r = 13 then
                    weight_o <= x"1E"; -- 30
                elsif position_r = 12 and rejectProduct_r = '0' then
                    weight_o <= x"50"; -- 80
                elsif position_r = 12 then
                    weight_o <= x"3C"; -- 60
                elsif position_r = 11 and rejectProduct_r = '0' then
                    weight_o <= x"64"; -- 100
                elsif position_r = 11 then
                    weight_o <= x"50"; -- 80
                elsif position_r = 10 and rejectProduct_r = '0' then
                    weight_o <= x"62"; -- 98
                elsif position_r = 10 then
                    weight_o <= x"4E"; -- 78
                elsif position_r = 9 and rejectProduct_r = '0' then
                    weight_o <= x"46"; -- 70
                elsif position_r = 9 then
                    weight_o <= x"32"; -- 50
                elsif position_r = 8 then
                    weight_o <= x"1E"; -- 30
                else
                    -- Empty positions are a real zero-weight stimulus.
                    weight_o <= x"00";
                end if;
            end if;
        end if;
    end process;
end rtl;
