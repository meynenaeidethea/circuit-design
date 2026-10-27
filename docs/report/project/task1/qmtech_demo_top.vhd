library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity qmtech_demo_top is
    port (clk50_i : in std_logic; nRst_btn_i : in std_logic; conveyorLed_n_o : out std_logic; rejectLed_n_o : out std_logic);
end qmtech_demo_top;

architecture structural of qmtech_demo_top is
    signal sensorA_s, sensorB_s, conveyorRun_s, reject_s : std_logic;
    signal resetSync_r : std_logic_vector(1 downto 0);
    signal nRst_s : std_logic;
    signal weight_s : std_logic_vector(7 downto 0);
begin
    -- Asynchronous assertion, synchronous release shared by both modules.
    reset_synchronizer : process(clk50_i, nRst_btn_i)
    begin
        if nRst_btn_i = '0' then
            resetSync_r <= (others => '0');
        elsif rising_edge(clk50_i) then
            resetSync_r(0) <= '1';
            resetSync_r(1) <= resetSync_r(0);
        end if;
    end process;
    nRst_s <= resetSync_r(1);

    flow_tester_inst : entity work.flow_tester
        generic map (STEP_CYCLES => 5_000_000)
        port map (clk_i => clk50_i, nRst_i => nRst_s, sensorA_o => sensorA_s, sensorB_o => sensorB_s, weight_o => weight_s);
    conveyor_sorter_inst : entity work.conveyor_sorter
        generic map (REJECT_PULSE_CYCLES => 5_000_000)
        port map (clk_i => clk50_i, nRst_i => nRst_s, sensorA_i => sensorA_s, sensorB_i => sensorB_s, weight_i => weight_s, conveyorRun_o => conveyorRun_s, reject_o => reject_s);
    conveyorLed_n_o <= not conveyorRun_s;
    rejectLed_n_o <= not reject_s;
end structural;
