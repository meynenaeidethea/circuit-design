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
    signal position_r : natural range 0 to 15;
    signal rejectProduct_r : std_logic;
begin
    step_count_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            stepCount_r <= 0;
        elsif rising_edge(clk_i) and stepCount_r = STEP_CYCLES - 1 then
            stepCount_r <= 0;
        elsif rising_edge(clk_i) then
            stepCount_r <= stepCount_r + 1;
        end if;
    end process;

    position_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            position_r <= 0;
        elsif rising_edge(clk_i) and stepCount_r = STEP_CYCLES - 1 and position_r = 15 then
            position_r <= 0;
        elsif rising_edge(clk_i) and stepCount_r = STEP_CYCLES - 1 then
            position_r <= position_r + 1;
        end if;
    end process;

    reject_product_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            rejectProduct_r <= '0';
        elsif rising_edge(clk_i) and stepCount_r = STEP_CYCLES - 1 and position_r = 15 then
            rejectProduct_r <= not rejectProduct_r;
        end if;
    end process;

    sensor_a_logic : process(all)
    begin
        sensorA_o <= '0';
        if position_r = 2 or position_r = 3 or position_r = 4 or position_r = 5 or position_r = 6 then
            sensorA_o <= '1';
        end if;
    end process;

    sensor_b_logic : process(all)
    begin
        sensorB_o <= '0';
        if position_r = 4 or position_r = 5 or position_r = 6 or position_r = 7 or position_r = 8 then
            sensorB_o <= '1';
        end if;
    end process;

    weight_logic : process(all)
    begin
        weight_o <= (others => '0');
        if position_r = 2 then
            weight_o <= std_logic_vector(to_unsigned(20, weight_o'length));
        elsif position_r = 3 and rejectProduct_r = '0' then
            weight_o <= std_logic_vector(to_unsigned(50, weight_o'length));
        elsif position_r = 3 and rejectProduct_r = '1' then
            weight_o <= std_logic_vector(to_unsigned(30, weight_o'length));
        elsif position_r = 4 and rejectProduct_r = '0' then
            weight_o <= std_logic_vector(to_unsigned(80, weight_o'length));
        elsif position_r = 4 and rejectProduct_r = '1' then
            weight_o <= std_logic_vector(to_unsigned(60, weight_o'length));
        elsif position_r = 5 and rejectProduct_r = '0' then
            weight_o <= std_logic_vector(to_unsigned(100, weight_o'length));
        elsif position_r = 5 and rejectProduct_r = '1' then
            weight_o <= std_logic_vector(to_unsigned(80, weight_o'length));
        elsif position_r = 6 and rejectProduct_r = '0' then
            weight_o <= std_logic_vector(to_unsigned(98, weight_o'length));
        elsif position_r = 6 and rejectProduct_r = '1' then
            weight_o <= std_logic_vector(to_unsigned(78, weight_o'length));
        elsif position_r = 7 and rejectProduct_r = '0' then
            weight_o <= std_logic_vector(to_unsigned(70, weight_o'length));
        elsif position_r = 7 and rejectProduct_r = '1' then
            weight_o <= std_logic_vector(to_unsigned(50, weight_o'length));
        elsif position_r = 8 then
            weight_o <= std_logic_vector(to_unsigned(30, weight_o'length));
        end if;
    end process;
end rtl;
