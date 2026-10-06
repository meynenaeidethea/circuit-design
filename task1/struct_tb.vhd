library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity struct_tb is
end struct_tb;

architecture simulation of struct_tb is
    constant CLOCK_PERIOD : time := 20 ns;
    signal clk_s         : std_logic := '0';
    signal nRst_s        : std_logic := '0';
    signal sensorA_s     : std_logic := '0';
    signal sensorB_s     : std_logic := '0';
    signal weight_s      : std_logic_vector(7 downto 0) := (others => '0');
    signal conveyorRun_s : std_logic;
    signal reject_s      : std_logic;
begin
    dut_inst : entity work.conveyor_sorter
        generic map (REJECT_PULSE_CYCLES => 3)
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
    begin
        nRst_s <= '0'; sensorA_s <= '0'; sensorB_s <= '0'; weight_s <= (others => '0');
        wait for CLOCK_PERIOD / 2;
        assert conveyorRun_s = '1' report "Conveyor must run during reset" severity failure;
        assert reject_s = '0' report "Reject output must be inactive during reset" severity failure;

        nRst_s <= '1'; wait until rising_edge(clk_s); wait for 1 ns;
        weight_s <= std_logic_vector(to_unsigned(100, weight_s'length)); sensorA_s <= '1';
        wait until rising_edge(clk_s); wait for 1 ns;
        sensorB_s <= '1'; wait until rising_edge(clk_s); wait for 1 ns;
        weight_s <= std_logic_vector(to_unsigned(98, weight_s'length));
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '0' report "A valid product must not enter reject state" severity failure;
        sensorA_s <= '0'; sensorB_s <= '0'; wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '0' report "A valid product must return without reject" severity failure;
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '0' report "Sorter did not return to waiting state after valid product" severity failure;

        weight_s <= std_logic_vector(to_unsigned(80, weight_s'length)); sensorA_s <= '1';
        wait until rising_edge(clk_s); wait for 1 ns;
        sensorB_s <= '1'; wait until rising_edge(clk_s); wait for 1 ns;
        weight_s <= std_logic_vector(to_unsigned(70, weight_s'length));
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '0' report "Reject starts only after check state" severity failure;
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '1' report "Out-of-range product must enter reject state" severity failure;
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '1' report "Reject pulse ended too early" severity failure;
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '1' report "Reject pulse must remain active for configured cycles" severity failure;
        wait until rising_edge(clk_s); wait for 1 ns;
        assert reject_s = '0' report "Reject pulse did not end after configured cycles" severity failure;
        sensorA_s <= '0'; sensorB_s <= '0'; wait until rising_edge(clk_s); wait for 1 ns;
        assert conveyorRun_s = '1' and reject_s = '0' report "Sorter did not return to waiting state" severity failure;
        report "All conveyor sorter checks passed" severity note;
        wait;
    end process;
end simulation;
