library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity conveyor_sorter is
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

architecture Behavioral of conveyor_sorter is

    type state_type is (
        WAIT_STATE,
        MEASURE_STATE,
        CHECK_STATE,
        REJECT_STATE,
        WAIT_CLEAR_STATE
    );

    signal control_state    : state_type;
    signal previousWeight_r : std_logic_vector(7 downto 0);
    signal measuredWeight_r : std_logic_vector(7 downto 0);
    signal centerSeen_flag  : std_logic;

begin

    process(clk_i, nRst_i)
    begin

        if nRst_i = '0' then

            control_state    <= WAIT_STATE;
            previousWeight_r <= (others => '0');
            measuredWeight_r <= (others => '0');
            centerSeen_flag  <= '0';

        elsif rising_edge(clk_i) then

            case control_state is

                when WAIT_STATE =>

                    previousWeight_r <= weight_i;
                    centerSeen_flag  <= '0';

                    if sensorA_i = '1' or sensorB_i = '1' then
                        control_state <= MEASURE_STATE;
                    end if;

                when MEASURE_STATE =>

                    if sensorA_i = '1' and sensorB_i = '1' then
                        centerSeen_flag <= '1';
                    end if;

                    if unsigned(weight_i) < unsigned(previousWeight_r)
                       and
                       (
                           centerSeen_flag = '1'
                           or
                           (sensorA_i = '1' and sensorB_i = '1')
                       ) then

                        measuredWeight_r <= previousWeight_r;
                        control_state    <= CHECK_STATE;

                    elsif sensorA_i = '0'
                          and sensorB_i = '0'
                          and centerSeen_flag = '1' then

                        measuredWeight_r <= previousWeight_r;
                        control_state    <= CHECK_STATE;

                    else

                        previousWeight_r <= weight_i;

                    end if;

                when CHECK_STATE =>

                    if unsigned(measuredWeight_r) >= to_unsigned(95, measuredWeight_r'length)
                       and
                       unsigned(measuredWeight_r) <= to_unsigned(105, measuredWeight_r'length) then

                        control_state <= WAIT_CLEAR_STATE;

                    else

                        control_state <= REJECT_STATE;

                    end if;

                when REJECT_STATE =>

                    control_state <= WAIT_CLEAR_STATE;

                when WAIT_CLEAR_STATE =>

                    if sensorA_i = '0' and sensorB_i = '0' then
                        control_state <= WAIT_STATE;
                    end if;

            end case;

        end if;

    end process;

    conveyorRun_o <= '1';

    reject_o <= '1' when control_state = REJECT_STATE else '0';

end Behavioral;
