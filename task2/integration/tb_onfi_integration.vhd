library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity tb_onfi_integration is
end entity;

architecture sim of tb_onfi_integration is
    component MX30LF1G18AC is
        port (
            CE_B, RE_B, WE_B, CLE, ALE, WP_B : in std_logic;
            RYBY_B : out std_logic;
            PT : in std_logic;
            IO : inout std_logic_vector(7 downto 0)
        );
    end component;
    constant byte_address : natural := 2048 + 3;
    signal clk_avalon, clk_logic : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal sink_data : word_t := (others => '0');
    signal sink_sop, sink_eop, sink_valid, sink_ready : std_logic := '0';
    signal sink_empty : std_logic_vector(2 downto 0) := (others => '0');
    signal source_data : word_t;
    signal source_sop, source_eop, source_valid : std_logic;
    signal source_empty : std_logic_vector(2 downto 0);
    signal source_ready : std_logic := '0';
    signal phy_rst_n, initialized, cmd_valid, cmd_ready : std_logic;
    signal phase : phase_t;
    signal w_data, r_data : word_t;
    signal w_last, w_valid, w_ready, r_last, r_valid, r_ready : std_logic;
    signal done : phase_result_t;
    signal done_valid, done_ready, recover_req, recover_ack, busy, fault : std_logic;
    signal ce_n, we_n, re_n, cle, ale, rb_n : std_logic;
    signal dq : byte_t;
    signal nand_busy_count, phase_count : natural := 0;

    function header(opcode : byte_t; id, length : natural) return word_t is
    begin
        return std_logic_vector(to_unsigned(length, 40)) & std_logic_vector(to_unsigned(id, 16)) & opcode;
    end function;

    function data_word(index : natural) return word_t is
        variable word_v : word_t := (others => '0');
        variable byte_index : natural;
    begin
        for lane in 0 to 7 loop
            byte_index := index * 8 + lane;
            if byte_index < 100 then
                word_v(8 * lane + 7 downto 8 * lane) := std_logic_vector(to_unsigned((17 * byte_index + 23) mod 256, 8));
            end if;
        end loop;
        return word_v;
    end function;
begin
    clk_avalon <= not clk_avalon after 10 ns;
    clk_logic <= not clk_logic after 4 ns;
    rb_n <= 'H';

    dut : entity work.onfi_integration_top
        port map (
            clk_avalon_i => clk_avalon, clk_logic_i => clk_logic, rst_ni => rst_n,
            sink_data_i => sink_data, sink_valid_i => sink_valid, sink_sop_i => sink_sop,
            sink_eop_i => sink_eop, sink_empty_i => sink_empty, sink_ready_o => sink_ready,
            source_data_o => source_data, source_valid_o => source_valid, source_sop_o => source_sop,
            source_eop_o => source_eop, source_empty_o => source_empty, source_ready_i => source_ready,
            phy_rst_no => phy_rst_n, phy_initialized_i => initialized,
            phase_o => phase, cmd_valid_o => cmd_valid, cmd_ready_i => cmd_ready,
            w_data_o => w_data, w_last_o => w_last, w_valid_o => w_valid, w_ready_i => w_ready,
            r_data_i => r_data, r_last_i => r_last, r_valid_i => r_valid, r_ready_o => r_ready,
            done_i => done, done_valid_i => done_valid, done_ready_o => done_ready,
            recover_req_o => recover_req, recover_ack_i => recover_ack, busy_o => busy, fault_o => fault
        );

    phy : entity work.tb_onfi_async_phy
        port map (
            clk_i => clk_logic, rst_ni => phy_rst_n, initialized_o => initialized,
            phase_i => phase, cmd_valid_i => cmd_valid, cmd_ready_o => cmd_ready,
            w_data_i => w_data, w_last_i => w_last, w_valid_i => w_valid, w_ready_o => w_ready,
            r_data_o => r_data, r_last_o => r_last, r_valid_o => r_valid, r_ready_i => r_ready,
            done_o => done, done_valid_o => done_valid, done_ready_i => done_ready,
            recover_req_i => recover_req, recover_ack_o => recover_ack,
            ce_no => ce_n, re_no => re_n, we_no => we_n, cle_o => cle, ale_o => ale,
            rb_ni => rb_n, dq_io => dq
        );

    nand_memory : MX30LF1G18AC
        port map (ce_n, re_n, we_n, cle, ale, '1', rb_n, '0', dq);

    process (rb_n)
    begin
        if falling_edge(rb_n) then
            nand_busy_count <= nand_busy_count + 1;
        end if;
    end process;

    process (clk_logic)
    begin
        if rising_edge(clk_logic) and cmd_valid = '1' and cmd_ready = '1' then
            phase_count <= phase_count + 1;
        end if;
    end process;

    process (clk_avalon)
        variable stalled : boolean := false;
        variable previous : std_logic_vector(68 downto 0);
        variable current : std_logic_vector(68 downto 0);
    begin
        if rising_edge(clk_avalon) then
            if rst_n = '0' then
                stalled := false;
            else
                current := source_sop & source_eop & source_empty & source_data;
                if stalled then
                    assert source_valid = '1' and current = previous
                        report "Avalon source changed a stalled beat" severity failure;
                end if;
                stalled := source_valid = '1' and source_ready = '0';
                previous := current;
                assert fault = '0' report "FSM entered FAULT" severity failure;
            end if;
        end if;
    end process;

    process
    begin
        wait for 8 ms;
        assert false report "Integration test watchdog expired" severity failure;
        wait;
    end process;

    process
        variable busy_before, phases_before : natural;

        procedure send_beat(data : word_t; sop, eop : std_logic; empty : natural := 0) is
        begin
            sink_data <= data;
            sink_sop <= sop;
            sink_eop <= eop;
            sink_empty <= std_logic_vector(to_unsigned(empty, 3));
            sink_valid <= '1';
            wait until rising_edge(clk_avalon) and sink_ready = '1';
            wait for 1 ns;
            sink_valid <= '0';
        end procedure;

        procedure send_read(id : natural) is
        begin
            send_beat(header(x"01", id, 100), '1', '0');
            send_beat(std_logic_vector(to_unsigned(byte_address, 64)), '0', '1');
        end procedure;

        procedure expect_beat(data : word_t; sop, eop : std_logic; empty : natural := 0;
                              stalls : positive := 2) is
        begin
            wait until rising_edge(clk_avalon) and source_valid = '1';
            for elapsed in 1 to stalls loop
                wait until rising_edge(clk_avalon);
            end loop;
            source_ready <= '1';
            wait until rising_edge(clk_avalon);
            assert source_valid = '1' and source_data = data and source_sop = sop and
                   source_eop = eop and unsigned(source_empty) = empty
                report "Avalon response mismatch, got " & to_hstring(source_data) &
                       " expected " & to_hstring(data) severity failure;
            wait for 1 ns;
            source_ready <= '0';
        end procedure;

        procedure expect_read(id : natural) is
        begin
            expect_beat(header(x"01", id, 100), '1', '0');
            expect_beat(x"00000000FFFF0000", '0', '0');
            for i in 0 to 11 loop
                expect_beat(data_word(i), '0', '0');
            end loop;
            expect_beat(data_word(12), '0', '1', 4, 9);
        end procedure;

        procedure expect_idle is
        begin
            for elapsed in 1 to 12 loop
                wait until rising_edge(clk_avalon);
                assert source_valid = '0' report "Unexpected additional response beat" severity failure;
            end loop;
        end procedure;
    begin
        wait for 73 ns;
        rst_n <= '1';
        wait until initialized = '1';
        busy_before := nand_busy_count;

        send_beat(header(x"02", 16#31#, 100), '1', '0');
        send_beat(x"00FF" & std_logic_vector(to_unsigned(byte_address, 48)), '0', '0');
        for i in 0 to 11 loop
            send_beat(data_word(i), '0', '0');
        end loop;
        send_beat(data_word(12), '0', '1', 4);
        send_read(16#32#);
        expect_beat(header(x"02", 16#31#, 0), '1', '0');
        expect_beat(x"000000000000E000", '0', '1');
        expect_read(16#32#);
        expect_idle;
        assert nand_busy_count >= busy_before + 2 report "Program/read did not wait for NAND busy" severity failure;
        report "PASS Avalon-ST WRITE100 -> READ100 through Macronix NAND: 13 words, S/E and empty=4";

        phases_before := phase_count;
        send_beat(header(x"09", 16#33#, 512), '1', '0');
        send_beat(x"00FF" & std_logic_vector(to_unsigned(byte_address, 48)), '0', '0');
        for i in 0 to 63 loop
            send_beat(x"0000000000000000", '0', '0');
        end loop;
        send_beat(x"0000000000000000", '0', '1');
        send_beat(header(x"01", 16#34#, 100), '1', '0');
        send_beat(header(x"01", 16#35#, 100), '1', '0');
        send_beat(std_logic_vector(to_unsigned(byte_address, 64)), '0', '1', 1);
        expect_beat(header(x"09", 16#33#, 0), '1', '0');
        expect_beat(x"0000000000000003", '0', '1');
        expect_beat(header(x"01", 16#34#, 0), '1', '0');
        expect_beat(x"0000000000000002", '0', '1');
        expect_beat(header(x"01", 16#35#, 0), '1', '0');
        expect_beat(x"0000000000000002", '0', '1');
        assert phase_count = phases_before report "Malformed request reached PHY" severity failure;
        report "PASS 65 stored words drained, frame resync and incorrect empty rejected";

        send_read(16#36#);
        wait until rising_edge(clk_avalon) and source_valid = '1';
        send_beat(header(x"01", 16#37#, 100), '1', '0');
        wait for 105 ns;
        rst_n <= '0';
        wait for 93 ns;
        assert source_valid = '0' and sink_ready = '0' report "Reset left an active Avalon transfer" severity failure;
        rst_n <= '1';
        wait until initialized = '1';
        expect_idle;
        send_read(16#38#);
        expect_read(16#38#);
        expect_idle;
        report "PASS common reset flushed blocked response and partial request, NAND data retained";
        std.env.finish;
        wait;
    end process;
end architecture;
