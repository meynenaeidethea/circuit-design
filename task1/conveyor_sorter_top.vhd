library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity conveyor_sorter_top is
    port (
        clk50_i       : in  std_logic;
        nRst_btn_i    : in  std_logic;
        sensorA_i     : in  std_logic;
        sensorB_i     : in  std_logic;
        weight_i      : in  std_logic_vector(7 downto 0);
        conveyorRun_o : out std_logic;
        reject_o      : out std_logic;
        conveyorLed_n_o : out std_logic;
        rejectLed_n_o   : out std_logic
    );
end conveyor_sorter_top;

architecture Structural of conveyor_sorter_top is

    signal resetSync_r      : std_logic_vector(1 downto 0);
    signal sensorASync_r    : std_logic_vector(1 downto 0);
    signal sensorBSync_r    : std_logic_vector(1 downto 0);

    signal weightMeta_r     : std_logic_vector(7 downto 0);
    signal weightSync_r     : std_logic_vector(7 downto 0);
    signal weightPrevious_r : std_logic_vector(7 downto 0);
    signal weightStable_r   : std_logic_vector(7 downto 0);

    signal nRst_s           : std_logic;
    signal conveyorRun_s    : std_logic;
    signal reject_s         : std_logic;

begin

    process(clk50_i, nRst_btn_i)
    begin

        if nRst_btn_i = '0' then

            resetSync_r <= (others => '0');

        elsif rising_edge(clk50_i) then

            resetSync_r(0) <= '1';
            resetSync_r(1) <= resetSync_r(0);

        end if;

    end process;

    nRst_s <= resetSync_r(1);

    process(clk50_i, nRst_s)
    begin

        if nRst_s = '0' then

            sensorASync_r    <= (others => '0');
            sensorBSync_r    <= (others => '0');
            weightMeta_r     <= (others => '0');
            weightSync_r     <= (others => '0');
            weightPrevious_r <= (others => '0');
            weightStable_r   <= (others => '0');

        elsif rising_edge(clk50_i) then

            sensorASync_r(0) <= sensorA_i;
            sensorASync_r(1) <= sensorASync_r(0);

            sensorBSync_r(0) <= sensorB_i;
            sensorBSync_r(1) <= sensorBSync_r(0);

            weightMeta_r <= weight_i;
            weightSync_r <= weightMeta_r;

            if weightSync_r = weightPrevious_r then
                weightStable_r <= weightSync_r;
            end if;

            weightPrevious_r <= weightSync_r;

        end if;

    end process;

    dut_inst : entity work.conveyor_sorter
        generic map (
            WEIGHT_MIN          => 95,
            WEIGHT_MAX          => 105,
            REJECT_PULSE_CYCLES => 5000000
        )
        port map (
            clk_i         => clk50_i,
            nRst_i        => nRst_s,
            sensorA_i     => sensorASync_r(1),
            sensorB_i     => sensorBSync_r(1),
            weight_i      => weightStable_r,
            conveyorRun_o => conveyorRun_s,
            reject_o      => reject_s
        );

    conveyorRun_o <= conveyorRun_s;
    reject_o      <= reject_s;

    conveyorLed_n_o <= not conveyorRun_s;
    rejectLed_n_o   <= not reject_s;

end Structural;