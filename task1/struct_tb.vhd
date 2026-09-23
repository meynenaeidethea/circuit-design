library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity struct_tb is
end struct_tb;

architecture Behavioral of struct_tb is

    signal clk_s         : std_logic := '0';
    signal nRst_s        : std_logic := '0';
    signal sensorA_s     : std_logic;
    signal sensorB_s     : std_logic;
    signal weight_s      : std_logic_vector(7 downto 0);
    signal conveyorRun_s : std_logic;
    signal reject_s      : std_logic;

begin

    clk_s <= not clk_s after 10 ns;

    process
    begin

        nRst_s <= '0';
        wait for 40 ns;

        nRst_s <= '1';

        wait;

    end process;

    tester_inst : entity work.flow_tester
        port map (
            clk_i     => clk_s,
            nRst_i    => nRst_s,
            sensorA_o => sensorA_s,
            sensorB_o => sensorB_s,
            weight_o  => weight_s
        );

    dut_inst : entity work.conveyor_sorter
        port map (
            clk_i         => clk_s,
            nRst_i        => nRst_s,
            sensorA_i     => sensorA_s,
            sensorB_i     => sensorB_s,
            weight_i      => weight_s,
            conveyorRun_o => conveyorRun_s,
            reject_o      => reject_s
        );

end Behavioral;