library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity conveyor_sorter is
    generic (
        WEIGHT_MIN          : natural range 0 to 255 := 95;
        WEIGHT_MAX          : natural range 0 to 255 := 105;
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

    assert WEIGHT_MIN <= WEIGHT_MAX
        report "WEIGHT_MIN must not exceed WEIGHT_MAX" severity failure;

    state_transitions : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            state_r <= WAIT_STATE;
        elsif rising_edge(clk_i) then
            case state_r is
                when WAIT_STATE =>
                    if sensorA_i = '1' or sensorB_i = '1' then
                        state_r <= MEASURE_STATE;
                    end if;
                when MEASURE_STATE =>
                    if weight_i < previousWeight_r
                       and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')) then
                        state_r <= CHECK_STATE;
                    elsif sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1' then
                        state_r <= CHECK_STATE;
                    end if;
                when CHECK_STATE =>
                    if measuredWeight_r >= WEIGHT_MIN and measuredWeight_r <= WEIGHT_MAX then
                        state_r <= WAIT_CLEAR_STATE;
                    else
                        state_r <= REJECT_STATE;
                    end if;
                when REJECT_STATE =>
                    if rejectCount_r = 0 then
                        state_r <= WAIT_CLEAR_STATE;
                    end if;
                when WAIT_CLEAR_STATE =>
                    if sensorA_i = '0' and sensorB_i = '0' then
                        state_r <= WAIT_STATE;
                    end if;
            end case;
        end if;
    end process;

    data_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            previousWeight_r <= (others => '0');
            measuredWeight_r <= (others => '0');
            rejectCount_r    <= 0;
            centerFlag_r     <= '0';
        elsif rising_edge(clk_i) then
            if state_r = WAIT_STATE then
                previousWeight_r <= weight_i;
            elsif state_r = MEASURE_STATE
               and not ((weight_i < previousWeight_r
                         and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')))
                        or (sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1')) then
                previousWeight_r <= weight_i;
            end if;

            if state_r = MEASURE_STATE
               and ((weight_i < previousWeight_r
                     and (centerFlag_r = '1' or (sensorA_i = '1' and sensorB_i = '1')))
                    or (sensorA_i = '0' and sensorB_i = '0' and centerFlag_r = '1')) then
                measuredWeight_r <= previousWeight_r;
            end if;

            -- Первый из N тактов отбраковки начинается при входе в состояние.
            -- Загрузка N-1 обеспечивает верную длительность и при N=1.
            if state_r = CHECK_STATE then
                rejectCount_r <= REJECT_PULSE_CYCLES - 1;
            elsif state_r = REJECT_STATE and rejectCount_r /= 0 then
                rejectCount_r <= rejectCount_r - 1;
            end if;

            if state_r = WAIT_STATE then
                centerFlag_r <= '0';
            elsif state_r = MEASURE_STATE and sensorA_i = '1' and sensorB_i = '1' then
                centerFlag_r <= '1';
            end if;
        end if;
    end process;

    conveyorRun_o <= '1';
    reject_o <= '1' when state_r = REJECT_STATE else '0';

end rtl;
