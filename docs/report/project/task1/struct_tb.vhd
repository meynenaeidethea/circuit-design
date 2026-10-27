library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity struct_tb is
    generic (REJECT_CYCLES : positive := 3);
end struct_tb;

architecture simulation of struct_tb is
    constant CLOCK_PERIOD : time := 20 ns;
    signal done_s        : boolean := false;
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
        while not done_s loop
            clk_s <= '0'; wait for CLOCK_PERIOD / 2;
            clk_s <= '1'; wait for CLOCK_PERIOD / 2;
        end loop;
        wait;
    end process;

    watchdog : process
    begin
        wait until done_s for 100 us;
        assert done_s report "struct_tb timeout" severity failure;
        wait;
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
            weight_s <= IEEE.STD_LOGIC_ARITH.CONV_STD_LOGIC_VECTOR(target_weight, weight_s'length);
            sensorA_s <= '1';
            sensorB_s <= '0';
            tick;
            sensorB_s <= '1';
            tick;
            weight_s <= IEEE.STD_LOGIC_ARITH.CONV_STD_LOGIC_VECTOR(target_weight - 1, weight_s'length);
            tick;
            assert reject_s = '0'
                report "Reject must remain inactive during the check state" severity failure;
            tick;
            assert reject_s = expected_reject
                report "Product was classified incorrectly" severity failure;

            if expected_reject = '1' then
                for cycle in 2 to REJECT_CYCLES loop
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
        check_product(255, '1');
        check_product(1, '1');

        reset_dut;
        weight_s <= x"00";
        sensorA_s <= '1';
        sensorB_s <= '1';
        tick;
        tick;
        sensorA_s <= '0';
        sensorB_s <= '0';
        tick;
        assert reject_s = '0' report "Zero weight must pass through CHECK_STATE" severity failure;
        tick;
        for cycle in 1 to REJECT_CYCLES loop
            assert reject_s = '1' report "Zero weight must be rejected for exactly N cycles" severity failure;
            tick;
        end loop;
        assert reject_s = '0' report "Zero-weight rejection did not end" severity failure;
        tick;
        tick;
        check_product(100, '0');

        reset_dut;
        weight_s <= x"6E";
        sensorA_s <= '1';
        tick;
        sensorA_s <= '0';
        weight_s <= (others => '0');
        tick;
        tick;
        assert reject_s = '0'
            report "Measurement without center detection must not be completed" severity failure;

        reset_dut;
        weight_s <= x"50";
        sensorA_s <= '1';
        tick;
        sensorB_s <= '1';
        tick;
        weight_s <= x"4F";
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
        done_s <= true;
        wait;
    end process;
end simulation;
