library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity flow_tester is
    generic (STEP_CYCLES : positive := 5_000_000);
    port (
        clk_i     : in  std_logic;
        nRst_i    : in  std_logic;
        sensorA_o : out std_logic;
        sensorB_o : out std_logic;
        weight_o  : out std_logic_vector(7 downto 0)
    );
end flow_tester;

architecture rtl of flow_tester is
    constant LAST_POSITION : natural := 15;
    subtype position_type is natural range 0 to LAST_POSITION;
    subtype weight_type is std_logic_vector(7 downto 0);

    type sample_type is record
        sensorA      : std_logic;
        sensorB      : std_logic;
        validWeight  : weight_type;
        rejectWeight : weight_type;
    end record;
    type profile_type is array (position_type) of sample_type;

    -- Датчики A и B, затем вес годного и бракованного изделия.
    constant EMPTY_SAMPLE : sample_type := ('0', '0', x"00", x"00");
    constant PROFILE : profile_type := (
        2 => ('1', '0', x"14", x"14"), -- 20 / 20
        3 => ('1', '0', x"32", x"1E"), -- 50 / 30
        4 => ('1', '1', x"50", x"3C"), -- 80 / 60
        5 => ('1', '1', x"64", x"50"), -- 100 / 80
        6 => ('1', '1', x"62", x"4E"), -- 98 / 78
        7 => ('0', '1', x"46", x"32"), -- 70 / 50
        8 => ('0', '1', x"1E", x"1E"), -- 30 / 30
        others => EMPTY_SAMPLE
    );

    signal stepCount_r     : natural range 0 to STEP_CYCLES - 1;
    signal nextPosition_r  : position_type;
    signal rejectProduct_r : std_logic;
    signal stepEnable_s    : boolean;
begin
    stepEnable_s <= stepCount_r = 0;

    counter_registers : process(clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            stepCount_r <= STEP_CYCLES - 1;
            -- Позиция 0 уже выставлена сбросом. Следующей будет позиция 1.
            nextPosition_r <= LAST_POSITION - 1;
            rejectProduct_r <= '0';
        elsif rising_edge(clk_i) then
            if stepEnable_s then
                stepCount_r <= STEP_CYCLES - 1;
                if nextPosition_r = 0 then
                    nextPosition_r <= LAST_POSITION;
                    rejectProduct_r <= not rejectProduct_r;
                else
                    nextPosition_r <= nextPosition_r - 1;
                end if;
            else
                stepCount_r <= stepCount_r - 1;
            end if;
        end if;
    end process;

    output_registers : process(clk_i, nRst_i)
        variable sample_v : sample_type;
    begin
        if nRst_i = '0' then
            sensorA_o <= PROFILE(0).sensorA;
            sensorB_o <= PROFILE(0).sensorB;
            weight_o <= PROFILE(0).validWeight;
        elsif rising_edge(clk_i) then
            if stepEnable_s then
                sample_v := PROFILE(LAST_POSITION - nextPosition_r);
                sensorA_o <= sample_v.sensorA;
                sensorB_o <= sample_v.sensorB;
                if rejectProduct_r = '0' then
                    weight_o <= sample_v.validWeight;
                else
                    weight_o <= sample_v.rejectWeight;
                end if;
            end if;
        end if;
    end process;
end rtl;
