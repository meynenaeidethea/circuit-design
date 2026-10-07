library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.ALL;

entity flow_tester_tb is
end flow_tester_tb;

architecture simulation of flow_tester_tb is
    constant CLOCK_PERIOD : time := 20 ns;
    constant STEP_CYCLES : positive := 8;
    constant REJECT_CYCLES : positive := 3;
    signal clk_s : std_logic := '0';
    signal nRst_s : std_logic := '0';
    signal sensorA_s, sensorB_s, conveyorRun_s, reject_s : std_logic;
    signal weight_s : std_logic_vector(7 downto 0);
    signal rejectPulses_s : natural := 0;
begin
    clk_s <= not clk_s after CLOCK_PERIOD / 2;

    generator_inst : entity work.flow_tester
        generic map (STEP_CYCLES => STEP_CYCLES)
        port map (clk_i => clk_s, nRst_i => nRst_s,
                  sensorA_o => sensorA_s, sensorB_o => sensorB_s, weight_o => weight_s);

    sorter_inst : entity work.conveyor_sorter
        generic map (REJECT_PULSE_CYCLES => REJECT_CYCLES)
        port map (clk_i => clk_s, nRst_i => nRst_s,
                  sensorA_i => sensorA_s, sensorB_i => sensorB_s, weight_i => weight_s,
                  conveyorRun_o => conveyorRun_s, reject_o => reject_s);

    monitor : process
        variable previousReject_v : std_logic := '0';
        variable pulseCycles_v : natural := 0;
    begin
        wait until rising_edge(clk_s);
        wait for 1 ns;
        assert conveyorRun_s = '1' report "Conveyor must remain enabled" severity failure;
        if nRst_s = '0' then
            rejectPulses_s <= 0;
            previousReject_v := '0';
            pulseCycles_v := 0;
            assert reject_s = '0' report "Reject must be inactive during reset" severity failure;
        else
            if reject_s = '1' then
                if previousReject_v = '0' then
                    rejectPulses_s <= rejectPulses_s + 1;
                end if;
                pulseCycles_v := pulseCycles_v + 1;
            elsif previousReject_v = '1' then
                assert pulseCycles_v = REJECT_CYCLES
                    report "Reject pulse has incorrect duration" severity failure;
                pulseCycles_v := 0;
            end if;
            previousReject_v := reject_s;
        end if;
    end process;

    stimulus : process
        procedure tick is
        begin
            wait until rising_edge(clk_s);
            wait for 2 ns;
        end procedure;

        procedure check_product(productIndex : natural) is
            variable expectedPeak_v : natural;
        begin
            if productIndex mod 2 = 0 then
                expectedPeak_v := 100;
            else
                expectedPeak_v := 80;
            end if;
            for cycle in 1 to 16 * STEP_CYCLES loop
                tick;
                if cycle = 5 * STEP_CYCLES then
                    assert sensorA_s = '1' and sensorB_s = '1'
                        report "Both sensors must be active at the peak" severity failure;
                    assert to_integer(unsigned(weight_s)) = expectedPeak_v
                        report "Incorrect alternating weight profile" severity failure;
                end if;
            end loop;
            assert rejectPulses_s = (productIndex + 1) / 2
                report "Only alternate, invalid products must be rejected" severity failure;
            assert reject_s = '0' report "Reject must end before the next product" severity failure;
        end procedure;
    begin
        tick;
        tick;
        nRst_s <= '1';
        -- Valid, invalid, valid: the next scheduled profile would be invalid.
        for product in 0 to 2 loop
            check_product(product);
        end loop;
        -- Reset must restore the valid-first sequence.
        nRst_s <= '0';
        tick;
        tick;
        nRst_s <= '1';
        check_product(0);
        check_product(1);
        report "All alternating flow checks passed" severity note;
        stop;
        wait;
    end process;
end simulation;
