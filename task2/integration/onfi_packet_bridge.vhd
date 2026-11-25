library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity onfi_packet_bridge is
    port (
        clk_i, rst_ni : in std_logic;
        in_data_i : in std_logic_vector(68 downto 0);
        in_valid_i : in std_logic;
        in_ready_o : out std_logic;
        out_data_o : out std_logic_vector(68 downto 0);
        out_valid_o : out std_logic;
        out_ready_i : in std_logic;
        req_o : out request_t;
        req_valid_o : out std_logic;
        req_ready_i : in std_logic;
        req_data_o : out word_t;
        req_data_valid_o : out std_logic;
        req_data_ready_i : in std_logic;
        rsp_i : in response_t;
        rsp_valid_i : in std_logic;
        rsp_ready_o : out std_logic;
        rsp_data_i : in word_t;
        rsp_data_valid_i : in std_logic;
        rsp_data_ready_o : out std_logic
    );
end entity;

architecture rtl of onfi_packet_bridge is
    type rx_state_t is (start_packet, take_header, take_body, discard_tail, send_descriptor,
                        fetch_request, capture_request, send_request);
    type tx_state_t is (collect, send_word0, send_word1, fetch_response, capture_response, send_response);
    type request_mem_t is array (0 to 64) of word_t;
    type response_mem_t is array (0 to 63) of word_t;
    signal request_mem_r : request_mem_t;
    signal response_mem_r : response_mem_t;
    signal rx_state : rx_state_t;
    signal tx_state : tx_state_t;
    signal req_r : request_t;
    signal rsp_r : response_t;
    signal seq_count : unsigned(15 downto 0);
    signal saved_count : natural range 0 to 65;
    signal req_index_count : natural range 0 to 64;
    signal rsp_index_count : natural range 0 to 63;
    signal collected_count : natural range 0 to 64;
    signal rsp_tail_r : unsigned(2 downto 0);
    signal req_read_r, rsp_read_r, req_word_r, rsp_word_r : word_t;
    signal sop_s, eop_s, body_expected_s : std_logic;
    signal in_word_s : word_t;
    signal empty_s : unsigned(2 downto 0);

    function read_class(opcode : byte_t) return std_logic is
    begin
        case opcode is
            when x"01" | x"03" | x"04" | x"08" | x"0A" => return '1';
            when others => return '0';
        end case;
    end function;

    function pack_beat(data : word_t; sop, eop : std_logic; empty : unsigned(2 downto 0))
        return std_logic_vector is
    begin
        return sop & eop & std_logic_vector(empty) & data;
    end function;
begin
    sop_s <= in_data_i(68);
    eop_s <= in_data_i(67);
    empty_s <= unsigned(in_data_i(66 downto 64));
    in_word_s <= in_data_i(63 downto 0);
    body_expected_s <= '1' when req_r.word0(7 downto 0) = x"02" or
                               req_r.word0(7 downto 0) = x"09" or
                               req_r.word0(7 downto 0) = x"0B" else '0';
    in_ready_o <= '1' when rst_ni = '1' and
                          (rx_state = start_packet or
                           ((rx_state = take_header or rx_state = take_body or rx_state = discard_tail) and
                            (in_valid_i = '0' or sop_s = '0'))) else '0';
    req_o <= req_r;
    req_valid_o <= '1' when rst_ni = '1' and rx_state = send_descriptor else '0';
    req_data_o <= req_word_r;
    req_data_valid_o <= '1' when rst_ni = '1' and rx_state = send_request else '0';
    rsp_ready_o <= '1' when rst_ni = '1' and tx_state = collect else '0';
    rsp_data_ready_o <= '1' when rst_ni = '1' and tx_state = collect and collected_count < 64 else '0';
    out_valid_o <= '1' when rst_ni = '1' and
                            (tx_state = send_word0 or tx_state = send_word1 or tx_state = send_response) else '0';

    process (all)
        variable word_s : word_t;
        variable last_lane : natural range 0 to 7;
    begin
        word_s := rsp_word_r;
        out_data_o <= (others => '0');
        case tx_state is
            when send_word0 =>
                out_data_o <= pack_beat(rsp_r.word0, '1', '0', "000");
            when send_word1 =>
                if collected_count = 0 then
                    out_data_o <= pack_beat(rsp_r.word1, '0', '1', "000");
                else
                    out_data_o <= pack_beat(rsp_r.word1, '0', '0', "000");
                end if;
            when send_response =>
                if rsp_index_count = 0 then
                    word_s(7 downto 0) := word_s(7 downto 0) and rsp_r.word1(23 downto 16);
                end if;
                if rsp_index_count + 1 = collected_count then
                    last_lane := 7 - to_integer(rsp_tail_r);
                    word_s(8 * last_lane + 7 downto 8 * last_lane) :=
                        word_s(8 * last_lane + 7 downto 8 * last_lane) and rsp_r.word1(31 downto 24);
                    out_data_o <= pack_beat(word_s, '0', '1', rsp_tail_r);
                else
                    out_data_o <= pack_beat(word_s, '0', '0', "000");
                end if;
            when others => null;
        end case;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rx_state = take_body and in_ready_o = '1' and in_valid_i = '1' then
                request_mem_r(saved_count) <= in_word_s;
            end if;
            if rx_state = fetch_request then
                req_read_r <= request_mem_r(req_index_count);
            end if;
            if rx_state = capture_request then
                req_word_r <= req_read_r;
            end if;
            if rsp_data_valid_i = '1' and rsp_data_ready_o = '1' then
                response_mem_r(collected_count) <= rsp_data_i;
            end if;
            if tx_state = fetch_response then
                rsp_read_r <= response_mem_r(rsp_index_count);
            end if;
            if tx_state = capture_response then
                rsp_word_r <= rsp_read_r;
            end if;
        end if;
    end process;

    process (clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            rx_state <= start_packet;
            seq_count <= (others => '0');
            saved_count <= 0;
            req_index_count <= 0;
        elsif rising_edge(clk_i) then
            if in_valid_i = '1' and sop_s = '1' and
               (rx_state = take_header or rx_state = take_body or rx_state = discard_tail) then
                req_r.frame_error <= '1';
                req_r.body_words <= to_unsigned(saved_count, 7);
                rx_state <= send_descriptor;
            else
                case rx_state is
                    when start_packet =>
                        if in_valid_i = '1' and sop_s = '1' then
                            req_r.word0 <= in_word_s;
                            req_r.word1 <= (others => '0');
                            req_r.seq <= seq_count;
                            req_r.read_class <= read_class(in_word_s(7 downto 0));
                            req_r.body_words <= (others => '0');
                            req_r.tail_empty <= (others => '0');
                            req_r.frame_error <= '0';
                            saved_count <= 0;
                            if eop_s = '1' then
                                req_r.frame_error <= '1';
                                rx_state <= send_descriptor;
                            else
                                if empty_s /= 0 then
                                    req_r.frame_error <= '1';
                                end if;
                                rx_state <= take_header;
                            end if;
                        end if;
                    when take_header =>
                        if in_valid_i = '1' then
                            req_r.word1 <= in_word_s;
                            if eop_s = '1' then
                                if body_expected_s = '1' or empty_s /= 0 then
                                    req_r.frame_error <= '1';
                                end if;
                                rx_state <= send_descriptor;
                            elsif body_expected_s = '1' then
                                if empty_s /= 0 then
                                    req_r.frame_error <= '1';
                                end if;
                                rx_state <= take_body;
                            else
                                req_r.frame_error <= '1';
                                rx_state <= discard_tail;
                            end if;
                        end if;
                    when take_body =>
                        if in_valid_i = '1' then
                            saved_count <= saved_count + 1;
                            if eop_s = '1' then
                                req_r.body_words <= to_unsigned(saved_count + 1, 7);
                                req_r.tail_empty <= empty_s;
                                rx_state <= send_descriptor;
                            elsif saved_count = 64 then
                                req_r.frame_error <= '1';
                                req_r.body_words <= to_unsigned(65, 7);
                                rx_state <= discard_tail;
                            elsif empty_s /= 0 then
                                req_r.frame_error <= '1';
                            end if;
                        end if;
                    when discard_tail =>
                        if in_valid_i = '1' and eop_s = '1' then
                            rx_state <= send_descriptor;
                        end if;
                    when send_descriptor =>
                        if req_ready_i = '1' then
                            seq_count <= seq_count + 1;
                            req_index_count <= 0;
                            if saved_count = 0 then
                                rx_state <= start_packet;
                            else
                                rx_state <= fetch_request;
                            end if;
                        end if;
                    when fetch_request =>
                        rx_state <= capture_request;
                    when capture_request =>
                        rx_state <= send_request;
                    when send_request =>
                        if req_data_ready_i = '1' then
                            if req_index_count + 1 = saved_count then
                                rx_state <= start_packet;
                            else
                                req_index_count <= req_index_count + 1;
                                rx_state <= fetch_request;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    process (clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            tx_state <= collect;
            collected_count <= 0;
            rsp_index_count <= 0;
        elsif rising_edge(clk_i) then
            case tx_state is
                when collect =>
                    if rsp_data_valid_i = '1' and rsp_data_ready_o = '1' then
                        collected_count <= collected_count + 1;
                    end if;
                    if rsp_valid_i = '1' then
                        rsp_r <= rsp_i;
                        rsp_tail_r <= 0 - unsigned(rsp_i.word0(26 downto 24));
                        rsp_index_count <= 0;
                        tx_state <= send_word0;
                    end if;
                when send_word0 =>
                    if out_ready_i = '1' then
                        tx_state <= send_word1;
                    end if;
                when send_word1 =>
                    if out_ready_i = '1' then
                        if collected_count = 0 then
                            tx_state <= collect;
                        else
                            tx_state <= fetch_response;
                        end if;
                    end if;
                when fetch_response =>
                    tx_state <= capture_response;
                when capture_response =>
                    tx_state <= send_response;
                when send_response =>
                    if out_ready_i = '1' then
                        if rsp_index_count + 1 = collected_count then
                            collected_count <= 0;
                            tx_state <= collect;
                        else
                            rsp_index_count <= rsp_index_count + 1;
                            tx_state <= fetch_response;
                        end if;
                    end if;
            end case;
        end if;
    end process;
end architecture;
