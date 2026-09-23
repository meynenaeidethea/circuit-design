library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flow_tester is
    port (
        clk_i     : in  std_logic;
        nRst_i    : in  std_logic;
        sensorA_o : out std_logic;
        sensorB_o : out std_logic;
        weight_o  : out std_logic_vector(7 downto 0)
    );
end flow_tester;

architecture Behavioral of flow_tester is

    signal position_count : std_logic_vector(3 downto 0);

begin

    process(clk_i, nRst_i)
    begin

        if nRst_i = '0' then

            position_count <= (others => '0');

        elsif rising_edge(clk_i) then

            if unsigned(position_count) = 15 then
                position_count <= (others => '0');
            else
                position_count <= std_logic_vector(unsigned(position_count) + 1);
            end if;

        end if;

    end process;

    process(position_count)
    begin

        sensorA_o <= '0';
        sensorB_o <= '0';
        weight_o  <= (others => '0');

        case to_integer(unsigned(position_count)) is

            when 2 =>
                sensorA_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(20, 8));

            when 3 =>
                sensorA_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(50, 8));

            when 4 =>
                sensorA_o <= '1';
                sensorB_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(80, 8));

            when 5 =>
                sensorA_o <= '1';
                sensorB_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(100, 8));

            when 6 =>
                sensorA_o <= '1';
                sensorB_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(98, 8));

            when 7 =>
                sensorB_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(70, 8));

            when 8 =>
                sensorB_o <= '1';
                weight_o  <= std_logic_vector(to_unsigned(30, 8));

            when others =>
                sensorA_o <= '0';
                sensorB_o <= '0';
                weight_o  <= (others => '0');

        end case;

    end process;

end Behavioral;