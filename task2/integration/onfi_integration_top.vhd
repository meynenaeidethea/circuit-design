library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity onfi_integration_top is
    generic (
        g_phase_timeout_cycles : positive := 1250000;
        g_recover_timeout_cycles : positive := 1250000
    );
    port (
        clk_avalon_i, clk_logic_i, rst_ni : in std_logic;
        sink_data_i : in word_t;
        sink_valid_i, sink_sop_i, sink_eop_i : in std_logic;
        sink_empty_i : in std_logic_vector(2 downto 0);
        sink_ready_o : out std_logic;
        source_data_o : out word_t;
        source_valid_o, source_sop_o, source_eop_o : out std_logic;
        source_empty_o : out std_logic_vector(2 downto 0);
        source_ready_i : in std_logic;
        phy_rst_no : out std_logic;
        phy_initialized_i : in std_logic;
        phase_o : out phase_t;
        cmd_valid_o : out std_logic;
        cmd_ready_i : in std_logic;
        w_data_o : out word_t;
        w_last_o, w_valid_o : out std_logic;
        w_ready_i : in std_logic;
        r_data_i : in word_t;
        r_last_i, r_valid_i : in std_logic;
        r_ready_o : out std_logic;
        done_i : in phase_result_t;
        done_valid_i : in std_logic;
        done_ready_o : out std_logic;
        recover_req_o : out std_logic;
        recover_ack_i : in std_logic;
        busy_o, fault_o : out std_logic
    );
end entity;

architecture rtl of onfi_integration_top is
    signal avalon_release_r, logic_release_r : std_logic_vector(7 downto 0);
    signal avalon_up_s, logic_up_s : std_logic;
    signal ingress_in_s, ingress_out_s, egress_in_s, egress_out_s : std_logic_vector(68 downto 0);
    signal ingress_valid_s, ingress_ready_s, egress_valid_s, egress_ready_s : std_logic;
    signal egress_read_valid_s, egress_read_ready_s : std_logic;
    signal source_word_r : std_logic_vector(68 downto 0);
    signal source_valid_r : std_logic;
    signal req_s : request_t;
    signal rsp_s : response_t;
    signal req_data_s, rsp_data_s : word_t;
    signal req_valid_s, req_ready_s, req_data_valid_s, req_data_ready_s : std_logic;
    signal rsp_valid_s, rsp_ready_s, rsp_data_valid_s, rsp_data_ready_s : std_logic;
    attribute preserve : boolean;
    attribute preserve of avalon_release_r, logic_release_r : signal is true;
begin
    process (clk_avalon_i, rst_ni)
    begin
        if rst_ni = '0' then
            avalon_release_r <= (others => '0');
        elsif rising_edge(clk_avalon_i) then
            avalon_release_r <= avalon_release_r(6 downto 0) & '1';
        end if;
    end process;

    process (clk_logic_i, rst_ni)
    begin
        if rst_ni = '0' then
            logic_release_r <= (others => '0');
        elsif rising_edge(clk_logic_i) then
            logic_release_r <= logic_release_r(6 downto 0) & '1';
        end if;
    end process;

    avalon_up_s <= avalon_release_r(7);
    logic_up_s <= logic_release_r(7);
    phy_rst_no <= logic_up_s;
    ingress_in_s <= sink_sop_i & sink_eop_i & sink_empty_i & sink_data_i;

    ingress : entity work.onfi_stream_fifo
        port map (
            rst_ni, clk_avalon_i, clk_logic_i, avalon_up_s, logic_up_s,
            ingress_in_s, sink_valid_i, sink_ready_o,
            ingress_out_s, ingress_valid_s, ingress_ready_s
        );

    egress : entity work.onfi_stream_fifo
        port map (
            rst_ni, clk_logic_i, clk_avalon_i, logic_up_s, avalon_up_s,
            egress_in_s, egress_valid_s, egress_ready_s,
            egress_out_s, egress_read_valid_s, egress_read_ready_s
        );

    egress_read_ready_s <= not source_valid_r or source_ready_i;
    source_valid_o <= source_valid_r;
    source_sop_o <= source_word_r(68);
    source_eop_o <= source_word_r(67);
    source_empty_o <= source_word_r(66 downto 64);
    source_data_o <= source_word_r(63 downto 0);

    process (clk_avalon_i, avalon_up_s)
    begin
        if avalon_up_s = '0' then
            source_valid_r <= '0';
        elsif rising_edge(clk_avalon_i) then
            if egress_read_ready_s = '1' then
                source_valid_r <= egress_read_valid_s;
                if egress_read_valid_s = '1' then
                    source_word_r <= egress_out_s;
                end if;
            end if;
        end if;
    end process;

    bridge : entity work.onfi_packet_bridge
        port map (
            clk_i => clk_logic_i, rst_ni => logic_up_s,
            in_data_i => ingress_out_s, in_valid_i => ingress_valid_s, in_ready_o => ingress_ready_s,
            out_data_o => egress_in_s, out_valid_o => egress_valid_s, out_ready_i => egress_ready_s,
            req_o => req_s, req_valid_o => req_valid_s, req_ready_i => req_ready_s,
            req_data_o => req_data_s, req_data_valid_o => req_data_valid_s, req_data_ready_i => req_data_ready_s,
            rsp_i => rsp_s, rsp_valid_i => rsp_valid_s, rsp_ready_o => rsp_ready_s,
            rsp_data_i => rsp_data_s, rsp_data_valid_i => rsp_data_valid_s, rsp_data_ready_o => rsp_data_ready_s
        );

    sequencer : entity work.onfi_protocol_fsm
        generic map (
            g_page_bytes => 2048, g_pages_per_block => 64, g_blocks_per_lun => 1024,
            g_read_id_bytes => 5, g_mode_mask => "000001",
            g_phase_timeout_cycles => g_phase_timeout_cycles,
            g_recover_timeout_cycles => g_recover_timeout_cycles
        )
        port map (
            clk_i => clk_logic_i, rst_n_i => logic_up_s, phy_initialized_i => phy_initialized_i,
            req_i => req_s, req_valid_i => req_valid_s, req_ready_o => req_ready_s,
            req_data_i => req_data_s, req_data_valid_i => req_data_valid_s, req_data_ready_o => req_data_ready_s,
            rsp_o => rsp_s, rsp_valid_o => rsp_valid_s, rsp_ready_i => rsp_ready_s,
            rsp_data_o => rsp_data_s, rsp_data_valid_o => rsp_data_valid_s, rsp_data_ready_i => rsp_data_ready_s,
            phase_o => phase_o, cmd_valid_o => cmd_valid_o, cmd_ready_i => cmd_ready_i,
            w_data_o => w_data_o, w_last_o => w_last_o, w_valid_o => w_valid_o, w_ready_i => w_ready_i,
            r_data_i => r_data_i, r_last_i => r_last_i, r_valid_i => r_valid_i, r_ready_o => r_ready_o,
            done_i => done_i, done_valid_i => done_valid_i, done_ready_o => done_ready_o,
            recover_req_o => recover_req_o, recover_ack_i => recover_ack_i, busy_o => busy_o, fault_o => fault_o
        );
end architecture;
