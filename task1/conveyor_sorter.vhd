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
    signal nextState_s      : state_type;
    signal previousWeight_r : std_logic_vector(7 downto 0);
    signal measuredWeight_r : std_logic_vector(7 downto 0);
    signal rejectCount_r    : natural range 0 to REJECT_PULSE_CYCLES - 1;
    signal centerFlag_r     : std_logic;

begin

    state_register : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            state_r <= WAIT_STATE;
        elsif rising_edge(clk_i) then
            state_r <= nextState_s;
        end if;
    end process;

    next_state_logic : process(all)
    begin
        nextState_s <= state_r;
        case state_r is
            when WAIT_STATE =>
                if sensorA_i = '1' or sensorB_i = '1' then
                    nextState_s <= MEASURE_STATE;
                end if;
            when MEASURE_STATE =>
                if unsigned(weight_i) < unsigned(previousWeight_r)
                   and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')) then
                    nextState_s <= CHECK_STATE;
                elsif sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1' then
                    nextState_s <= CHECK_STATE;
                end if;
            when CHECK_STATE =>
                if to_integer(unsigned(measuredWeight_r)) >= WEIGHT_MIN
                   and to_integer(unsigned(measuredWeight_r)) <= WEIGHT_MAX then
                    nextState_s <= WAIT_CLEAR_STATE;
                else
                    nextState_s <= REJECT_STATE;
                end if;
            when REJECT_STATE =>
                if rejectCount_r = REJECT_PULSE_CYCLES - 1 then
                    nextState_s <= WAIT_CLEAR_STATE;
                end if;
            when WAIT_CLEAR_STATE =>
                if sensorA_i = '0' and sensorB_i = '0' then
                    nextState_s <= WAIT_STATE;
                end if;
        end case;
    end process;

    data_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            previousWeight_r <= (others => '0');
            measuredWeight_r <= (others => '0');
            rejectCount_r    <= 0;
            centerFlag_r     <= '0';
        elsif rising_edge(clk_i) then
            case state_r is
                when WAIT_STATE =>
                    previousWeight_r <= weight_i;
                    rejectCount_r    <= 0;
                    centerFlag_r     <= '0';
                when MEASURE_STATE =>
                    if sensorA_i = '1' and sensorB_i = '1' then
                        centerFlag_r <= '1';
                    end if;
                    if unsigned(weight_i) < unsigned(previousWeight_r)
                       and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')) then
                        measuredWeight_r <= previousWeight_r;
                    elsif sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1' then
                        measuredWeight_r <= previousWeight_r;
                    else
                        previousWeight_r <= weight_i;
                    end if;
                when CHECK_STATE =>
                    if to_integer(unsigned(measuredWeight_r)) < WEIGHT_MIN
                       or to_integer(unsigned(measuredWeight_r)) > WEIGHT_MAX then
                        rejectCount_r <= 0;
                    end if;
                when REJECT_STATE =>
                    if rejectCount_r = REJECT_PULSE_CYCLES - 1 then
                        rejectCount_r <= 0;
                    else
                        rejectCount_r <= rejectCount_r + 1;
                    end if;
                when WAIT_CLEAR_STATE =>
                    null;
            end case;
        end if;
    end process;

    output_logic : process(all)
    begin
        conveyorRun_o <= '1';
        reject_o      <= '0';
        if state_r = REJECT_STATE then
            reject_o <= '1';
        end if;
    end process;

end rtl;
