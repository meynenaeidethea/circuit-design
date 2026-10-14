library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity struct_tb is
end struct_tb;

architecture simulation of struct_tb is
    constant CLOCK_PERIOD : time := 20 ns;
    constant REJECT_CYCLES : positive := 3;
    signal clk_s         : std_logic := '0';
    signal nRst_s        : std_logic := '0';
    signal sensorA_s     : std_logic := '0';
    signal sensorB_s     : std_logic := '0';
    signal weight_s      : std_logic_vector(7 downto 0) := (others => '0');
    signal conveyorRun_s : std_logic;
    signal reject_s      : std_logic;
begin
    dut_inst : entity work.conveyor_sorter
        generic map (REJECT_PULSE_CYCLES => REJECT_CYCLES)
        port map (clk_i => clk_s, nRst_i => nRst_s, sensorA_i => sensorA_s, sensorB_i => sensorB_s,
                  weight_i => weight_s, conveyorRun_o => conveyorRun_s, reject_o => reject_s);

    clock_generator : process
    begin
        while true loop
            clk_s <= '0'; wait for CLOCK_PERIOD / 2;
            clk_s <= '1'; wait for CLOCK_PERIOD / 2;
        end loop;
    end process;

    stimulus_and_check : process
        procedure tick is
        begin
            wait until rising_edge(clk_s);
            wait for 1 ns;
        end procedure;

        procedure reset_dut is
        begin
            nRst_s <= '0';
            wait for 1 ns;
            assert conveyorRun_s = '1' and reject_s = '0'
                report "Reset must keep the conveyor enabled and reject inactive" severity failure;
            tick;
            nRst_s <= '1';
            tick;
        end procedure;

        procedure check_product(target_weight : natural; expected_reject : std_logic) is
        begin
            weight_s <= std_logic_vector(to_unsigned(target_weight, weight_s'length));
            sensorA_s <= '1';
            sensorB_s <= '0';
            tick;
            sensorB_s <= '1';
            tick;
            weight_s <= std_logic_vector(to_unsigned(target_weight - 1, weight_s'length));
            tick;
            assert reject_s = '0'
                report "Reject must remain inactive during the check state" severity failure;
            tick;
            assert reject_s = expected_reject
                report "Product was classified incorrectly" severity failure;

            if expected_reject = '1' then
                for cycle in 2 to REJECT_CYCLES - 1 loop
                    tick;
                    assert reject_s = '1'
                        report "Reject pulse ended before the configured duration" severity failure;
                end loop;
                tick;
                assert reject_s = '0'
                    report "Reject pulse exceeded the configured duration" severity failure;
            else
                tick;
                assert reject_s = '0'
                    report "Valid product entered the reject state" severity failure;
            end if;

            tick;
            assert reject_s = '0'
                report "Reject must remain inactive while waiting for sensor release" severity failure;
            sensorA_s <= '0';
            sensorB_s <= '0';
            tick;
            tick;
            assert conveyorRun_s = '1' and reject_s = '0'
                report "Sorter did not return to the waiting state" severity failure;
        end procedure;
    begin
        reset_dut;
        check_product(94, '1');
        check_product(95, '0');
        check_product(105, '0');
        check_product(106, '1');
        check_product(80, '1');

        reset_dut;
        weight_s <= std_logic_vector(to_unsigned(110, weight_s'length));
        sensorA_s <= '1';
        tick;
        sensorA_s <= '0';
        weight_s <= (others => '0');
        tick;
        tick;
        assert reject_s = '0'
            report "Measurement without center detection must not be completed" severity failure;

        reset_dut;
        weight_s <= std_logic_vector(to_unsigned(80, weight_s'length));
        sensorA_s <= '1';
        tick;
        sensorB_s <= '1';
        tick;
        weight_s <= std_logic_vector(to_unsigned(79, weight_s'length));
        tick;
        tick;
        assert reject_s = '1'
            report "Out-of-range product must enter the reject state" severity failure;
        nRst_s <= '0';
        wait for 1 ns;
        assert conveyorRun_s = '1' and reject_s = '0'
            report "Asynchronous reset must stop rejection immediately" severity failure;
        tick;
        nRst_s <= '1';
        sensorA_s <= '0';
        sensorB_s <= '0';
        tick;
        assert reject_s = '0'
            report "Sorter must remain reset after an interrupted reject pulse" severity failure;

        report "All conveyor sorter checks passed" severity note;
        wait;
    end process;
end simulation;
