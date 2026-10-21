library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity conveyor_sorter is
    generic (
        WEIGHT_MIN          : natural  := 95;
        WEIGHT_MAX          : natural  := 105;
        REJECT_PULSE_CYCLES : positive := 5_000_000
    );
    port (
        clk_i         : in  std_logic;
        nRst_i        : in  std_logic;
        sensorA_i     : in  std_logic;
        sensorB_i     : in  std_logic;
        weight_i      : in  std_logic_vector(7 downto 0);
        conveyorRun_o : out std_logic;
        reject_o      : out std_logic
    );
end conveyor_sorter;

architecture rtl of conveyor_sorter is

    type state_type is (WAIT_STATE, MEASURE_STATE, CHECK_STATE, REJECT_STATE, WAIT_CLEAR_STATE);

    signal state_r          : state_type;
    signal previousWeight_r : std_logic_vector(7 downto 0);
    signal measuredWeight_r : std_logic_vector(7 downto 0);
    signal rejectCount_r    : natural range 0 to REJECT_PULSE_CYCLES - 1;
    signal centerFlag_r     : std_logic;

begin

    state_transitions : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            state_r <= WAIT_STATE;
        elsif rising_edge(clk_i) and state_r = WAIT_STATE and (sensorA_i = '1' or sensorB_i = '1') then
            state_r <= MEASURE_STATE;
        elsif rising_edge(clk_i) and state_r = MEASURE_STATE
           and ((unsigned(weight_i) < unsigned(previousWeight_r)
                 and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')))
                or (sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1')) then
            state_r <= CHECK_STATE;
        elsif rising_edge(clk_i) and state_r = CHECK_STATE
           and to_integer(unsigned(measuredWeight_r)) >= WEIGHT_MIN
           and to_integer(unsigned(measuredWeight_r)) <= WEIGHT_MAX then
            state_r <= WAIT_CLEAR_STATE;
        elsif rising_edge(clk_i) and state_r = CHECK_STATE
           and (to_integer(unsigned(measuredWeight_r)) < WEIGHT_MIN
                or to_integer(unsigned(measuredWeight_r)) > WEIGHT_MAX) then
            state_r <= REJECT_STATE;
        elsif rising_edge(clk_i) and state_r = REJECT_STATE
           and rejectCount_r = REJECT_PULSE_CYCLES - 1 then
            state_r <= WAIT_CLEAR_STATE;
        elsif rising_edge(clk_i) and state_r = WAIT_CLEAR_STATE
           and sensorA_i = '0' and sensorB_i = '0' then
            state_r <= WAIT_STATE;
        end if;
    end process;

    previous_weight_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            previousWeight_r <= (others => '0');
        elsif rising_edge(clk_i) and state_r = WAIT_STATE then
            previousWeight_r <= weight_i;
        elsif rising_edge(clk_i) and state_r = MEASURE_STATE
           and not ((unsigned(weight_i) < unsigned(previousWeight_r)
                     and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')))
                    or (sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1')) then
            previousWeight_r <= weight_i;
        end if;
    end process;

    measured_weight_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            measuredWeight_r <= (others => '0');
        elsif rising_edge(clk_i) and state_r = MEASURE_STATE
           and ((unsigned(weight_i) < unsigned(previousWeight_r)
                 and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')))
                or (sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1')) then
            measuredWeight_r <= previousWeight_r;
        end if;
    end process;

    reject_count_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            rejectCount_r <= 0;
        elsif rising_edge(clk_i) and state_r = WAIT_STATE then
            rejectCount_r <= 0;
        elsif rising_edge(clk_i) and state_r = CHECK_STATE
           and (to_integer(unsigned(measuredWeight_r)) < WEIGHT_MIN
                or to_integer(unsigned(measuredWeight_r)) > WEIGHT_MAX) then
            rejectCount_r <= 0;
        elsif rising_edge(clk_i) and state_r = REJECT_STATE
           and rejectCount_r = REJECT_PULSE_CYCLES - 1 then
            rejectCount_r <= 0;
        elsif rising_edge(clk_i) and state_r = REJECT_STATE then
            rejectCount_r <= rejectCount_r + 1;
        end if;
    end process;

    center_flag_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            centerFlag_r <= '0';
        elsif rising_edge(clk_i) and state_r = WAIT_STATE then
            centerFlag_r <= '0';
        elsif rising_edge(clk_i) and state_r = MEASURE_STATE
           and sensorA_i = '1' and sensorB_i = '1' then
            centerFlag_r <= '1';
        end if;
    end process;

    conveyorRun_o <= '1';

    reject_output : process(all)
    begin
        reject_o <= '0';
        if state_r = REJECT_STATE then
            reject_o <= '1';
        end if;
    end process;

end rtl;
