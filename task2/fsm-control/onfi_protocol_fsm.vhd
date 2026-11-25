library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity onfi_protocol_fsm is
    generic (
        g_max_length : positive range 1 to 512 := 512;
        g_page_bytes : positive range 1 to 65536;
        g_pages_per_block : positive range 1 to 65536;
        g_blocks_per_lun : positive range 1 to 16777216;
        g_read_id_bytes : positive range 1 to 512;
        g_mode_mask : std_logic_vector(5 downto 0) := "000001";
        g_phase_timeout_cycles : positive := 1250000;
        g_recover_timeout_cycles : positive := 1250000
    );
    port (
        clk_i : in std_logic;
        rst_n_i : in std_logic;
        phy_initialized_i : in std_logic;
        req_i : in request_t;
        req_valid_i : in std_logic;
        req_ready_o : out std_logic;
        req_data_i : in word_t;
        req_data_valid_i : in std_logic;
        req_data_ready_o : out std_logic;
        rsp_o : out response_t;
        rsp_valid_o : out std_logic;
        rsp_ready_i : in std_logic;
        rsp_data_o : out word_t;
        rsp_data_valid_o : out std_logic;
        rsp_data_ready_i : in std_logic;
        phase_o : out phase_t;
        cmd_valid_o : out std_logic;
        cmd_ready_i : in std_logic;
        w_data_o : out word_t;
        w_last_o : out std_logic;
        w_valid_o : out std_logic;
        w_ready_i : in std_logic;
        r_data_i : in word_t;
        r_last_i : in std_logic;
        r_valid_i : in std_logic;
        r_ready_o : out std_logic;
        done_i : in phase_result_t;
        done_valid_i : in std_logic;
        done_ready_o : out std_logic;
        recover_req_o : out std_logic;
        recover_ack_i : in std_logic;
        busy_o : out std_logic;
        fault_o : out std_logic
    );
end entity;

architecture rtl of onfi_protocol_fsm is
    type state_t is (
        select_request, decode_address, check_frame, validate, dispatch, load_word, load_byte,
        decode_split, check_split,
        drain, prepare, configure_phase, issue,
        tx_fetch, tx_pack, tx_offer, rx_take, rx_store, wait_done,
        recover, recover_release, make_result, rsp_fetch, rsp_pack, rsp_offer,
        publish, fault
    );

    function maximum(a, b : positive) return positive is
    begin
        if a > b then
            return a;
        end if;
        return b;
    end function;

    constant ram_size : positive := maximum(g_max_length, 256);
    type buffer_t is array (0 to ram_size - 1) of byte_t;
    signal buffer_r : buffer_t;
    signal ram_read_r : byte_t;
    signal control_state : state_t := select_request;
    signal req_r : request_t;
    signal address_r : nand_address_t;
    signal address_in_range_r : boolean;
    signal end_column_r : unsigned(16 downto 0);
    signal selector_r : byte_t;
    signal length_r : natural range 0 to 1023;
    signal frame_valid_r, has_body_r : boolean;
    signal stored_count : natural range 0 to 127;
    signal split_column_r : unsigned(15 downto 0);
    signal split_length_r : natural range 0 to 1023;
    signal split_first_end_r, split_second_sum_r, split_second_limit_r : unsigned(16 downto 0);
    signal split_header_valid_r : boolean;
    signal segment_header_r : std_logic;
    signal status_r, nand_status_r : byte_t;
    signal validation_status_r : byte_t;
    signal payload_length_r : natural range 0 to g_max_length;
    signal step_index_count : natural range 0 to 10;
    signal step_r : step_t;
    signal phase_r : phase_t;
    signal phase_length_r : natural range 0 to ram_size;
    signal phase_timer_count : natural range 0 to g_phase_timeout_cycles - 1;
    signal recovery_timer_count : natural range 0 to g_recover_timeout_cycles - 1;
    signal transfer_count : natural range 0 to ram_size;
    signal buffer_index_count : natural range 0 to ram_size - 1;
    signal lane_count : natural range 0 to 7;
    signal input_word_r, output_word_r : word_t;
    signal w_last_r : std_logic;
    signal rx_last_word_r : std_logic;
    signal copy_count : natural range 0 to 2;
    signal crc_r, stored_crc_r : unsigned(15 downto 0);
    signal signature_r : std_logic;
    signal feature_supported_r : std_logic;
    signal advertised_modes_r : std_logic_vector(5 downto 0);
    signal candidate_features_r : std_logic;
    signal candidate_modes_r : std_logic_vector(5 downto 0);
    signal requested_mode_r, active_mode_r : unsigned(3 downto 0);
    signal phase_active_s, early_done_s, cmd_valid_s : std_logic;
    signal ram_write_s, ram_read_s : std_logic;
    signal ram_data_s : byte_t;
begin
    assert power_of_two(g_page_bytes) and power_of_two(g_pages_per_block)
        report "ONFI page geometry requires powers of two" severity failure;
    assert g_mode_mask(0) = '1'
        report "ONFI timing mode 0 must be supported" severity failure;

    req_ready_o <= '1' when rst_n_i = '1' and control_state = select_request and
                           phy_initialized_i = '1' and recover_ack_i = '0' else '0';
    req_data_ready_o <= '1' when rst_n_i = '1' and
                               (control_state = load_word or control_state = drain) else '0';
    rsp_valid_o <= '1' when rst_n_i = '1' and control_state = publish else '0';
    rsp_data_valid_o <= '1' when rst_n_i = '1' and control_state = rsp_offer else '0';
    rsp_data_o <= output_word_r;
    rsp_o <= (
        word0 => "000000" & x"000000" &
                 std_logic_vector(to_unsigned(payload_length_r, 10)) & req_r.word0(23 downto 0),
        word1 => x"00000000" & x"FFFF" & nand_status_r & status_r,
        seq => req_r.seq,
        read_class => req_r.read_class
    ) when payload_length_r /= 0 else (
        word0 => x"0000000000" & req_r.word0(23 downto 0),
        word1 => x"000000000000" & nand_status_r & status_r,
        seq => req_r.seq,
        read_class => req_r.read_class
    );

    phase_o <= phase_r;
    cmd_valid_s <= '1' when rst_n_i = '1' and control_state = issue else '0';
    cmd_valid_o <= cmd_valid_s;
    w_valid_o <= '1' when rst_n_i = '1' and control_state = tx_offer else '0';
    w_data_o <= output_word_r;
    w_last_o <= w_last_r;
    r_ready_o <= '1' when rst_n_i = '1' and control_state = rx_take else '0';
    early_done_s <= '1' when control_state = issue or control_state = tx_fetch or control_state = tx_pack or
                             control_state = tx_offer or control_state = rx_take or
                             (control_state = rx_store and rx_last_word_r = '0') else '0';
    done_ready_o <= '1' when rst_n_i = '1' and
                            (early_done_s = '1' or control_state = wait_done) else '0';
    phase_active_s <= '1' when control_state = issue or early_done_s = '1' or
                               control_state = rx_store or control_state = wait_done else '0';
    recover_req_o <= '1' when rst_n_i = '1' and control_state = recover else '0';
    busy_o <= '0' when control_state = select_request else '1';
    fault_o <= '1' when control_state = fault else '0';

    ram_write_s <= '1' when rst_n_i = '1' and
                            (control_state = load_byte or
                             (control_state = rx_store and
                              (step_r = read_result or step_r = read_parameters))) else '0';
    ram_read_s <= '1' when control_state = tx_fetch or control_state = rsp_fetch else '0';
    ram_data_s <= input_word_r(8 * lane_count + 7 downto 8 * lane_count);

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if ram_write_s = '1' then
                buffer_r(buffer_index_count) <= ram_data_s;
            elsif ram_read_s = '1' then
                ram_read_r <= buffer_r(buffer_index_count);
            end if;
        end if;
    end process;

    process (clk_i, rst_n_i)
        variable opcode : byte_t;
        variable raw_address, page_number, block_number : unsigned(47 downto 0);
        variable byte_count, expected_words, expected_empty : natural;
        variable rounded_length : unsigned(10 downto 0);
        variable first_count : natural;
        variable argument_valid, expected_last : boolean;
        variable result_code : byte_t;
        variable next_step : step_t;
        variable next_phase : phase_t;
        variable data_byte : byte_t;
    begin
        if rst_n_i = '0' then
            control_state <= select_request;
            feature_supported_r <= '0';
            advertised_modes_r <= (others => '0');
            active_mode_r <= (others => '0');
            phase_timer_count <= 0;
            recovery_timer_count <= 0;
            payload_length_r <= 0;
        elsif rising_edge(clk_i) then
            opcode := req_r.word0(7 downto 0);
            if phase_active_s = '1' and phase_timer_count < g_phase_timeout_cycles - 1 then
                phase_timer_count <= phase_timer_count + 1;
            end if;

            if r_valid_i = '1' and phase_r.kind = read_data and
               ((control_state = rx_store and rx_last_word_r = '1') or control_state = wait_done) then
                status_r <= status_internal_error;
                recovery_timer_count <= 0;
                control_state <= recover;
            elsif early_done_s = '1' and done_valid_i = '1' then
                case done_i is
                    when phase_timeout => status_r <= status_timeout;
                    when others => status_r <= status_internal_error;
                end case;
                recovery_timer_count <= 0;
                control_state <= recover;
            elsif phase_active_s = '1' and phase_timer_count = g_phase_timeout_cycles - 1 and
                  not (control_state = wait_done and done_valid_i = '1') then
                status_r <= status_timeout;
                recovery_timer_count <= 0;
                control_state <= recover;
            else
                case control_state is
                    when select_request =>
                        if req_valid_i = '1' and phy_initialized_i = '1' and recover_ack_i = '0' then
                            req_r <= req_i;
                            stored_count <= to_integer(req_i.body_words);
                            payload_length_r <= 0;
                            nand_status_r <= x"00";
                            control_state <= decode_address;
                        end if;

                    when decode_address =>
                        raw_address := unsigned(req_r.word1(47 downto 0));
                        page_number := raw_address / g_page_bytes;
                        block_number := page_number / g_pages_per_block;
                        address_in_range_r <= block_number < g_blocks_per_lun;
                        address_r.lun <= (others => '0');
                        address_r.page.block_index <= resize(block_number, 24);
                        address_r.page.page_in_block <= resize(page_number mod g_pages_per_block, 16);
                        address_r.column <= resize(raw_address mod g_page_bytes, 16);
                        end_column_r <= resize(raw_address mod g_page_bytes, 17) +
                                        resize(unsigned(req_r.word0(33 downto 24)), 17);
                        selector_r <= req_r.word1(7 downto 0);
                        length_r <= to_integer(unsigned(req_r.word0(33 downto 24)));
                        step_index_count <= 0;
                        copy_count <= 0;
                        buffer_index_count <= 0;
                        transfer_count <= 0;
                        segment_header_r <= '0';
                        if opcode = x"09" then
                            segment_header_r <= '1';
                        end if;
                        control_state <= check_frame;

                    when check_frame =>
                        expected_words := 0;
                        expected_empty := 0;
                        has_body_r <= opcode = x"02" or opcode = x"09" or opcode = x"0B";
                        if opcode = x"02" or opcode = x"09" or opcode = x"0B" then
                            rounded_length := to_unsigned(length_r, 11) + 7;
                            expected_words := to_integer(rounded_length(10 downto 3));
                            expected_empty := to_integer(not rounded_length(2 downto 0));
                            if opcode = x"09" then
                                expected_words := expected_words + 1;
                            end if;
                        end if;
                        frame_valid_r <= stored_count = expected_words and to_integer(req_r.tail_empty) = expected_empty;
                        control_state <= validate;

                    when validate =>
                        raw_address := unsigned(req_r.word1(47 downto 0));
                        byte_count := length_r;
                        argument_valid := true;
                        result_code := status_ok;

                        case opcode is
                            when x"01" | x"02" | x"08" | x"09" =>
                                argument_valid := address_in_range_r and byte_count /= 0 and
                                                  end_column_r <= g_page_bytes;
                            when x"03" =>
                                argument_valid := byte_count /= 0 and
                                                  ((raw_address = 0 and byte_count <= g_read_id_bytes) or
                                                   (raw_address = 32 and byte_count <= 4));
                            when x"04" =>
                                argument_valid := raw_address = 0 and byte_count /= 0 and byte_count <= 256;
                            when x"05" =>
                                argument_valid := address_in_range_r and address_r.column = 0 and byte_count = 0 and
                                                  address_r.page.page_in_block = 0;
                            when x"06" | x"07" =>
                                argument_valid := raw_address = 0 and byte_count = 0;
                            when x"0A" | x"0B" =>
                                argument_valid := raw_address = 1 and byte_count = 4;
                            when others =>
                                result_code := status_invalid_opcode;
                        end case;

                        if req_r.frame_error = '1' or unsigned(req_r.word0(63 downto 34)) /= 0 or
                           unsigned(req_r.word1(63 downto 56)) /= 0 then
                            result_code := status_bad_packet;
                        elsif result_code = status_ok then
                            if not frame_valid_r then
                                result_code := status_bad_packet;
                            elsif not argument_valid or byte_count > g_max_length then
                                result_code := status_invalid_argument;
                            elsif (opcode = x"09" and req_r.word1(55 downto 48) /= x"FF") or
                                  (opcode /= x"02" and opcode /= x"09" and req_r.word1(55 downto 48) /= x"00") then
                                result_code := status_invalid_argument;
                            elsif (opcode = x"0A" or opcode = x"0B") and feature_supported_r = '0' then
                                result_code := status_unsupported;
                            end if;
                        end if;

                        validation_status_r <= result_code;
                        control_state <= dispatch;

                    when dispatch =>
                        status_r <= validation_status_r;
                        if validation_status_r /= status_ok then
                            if stored_count = 0 then
                                control_state <= make_result;
                            else
                                control_state <= drain;
                            end if;
                        else
                            if has_body_r then
                                control_state <= load_word;
                            else
                                control_state <= prepare;
                            end if;
                        end if;

                    when load_word =>
                        if req_data_valid_i = '1' then
                            stored_count <= stored_count - 1;
                            if segment_header_r = '1' then
                                segment_header_r <= '0';
                                input_word_r <= req_data_i;
                                control_state <= decode_split;
                            elsif opcode = x"0B" and unsigned(req_data_i(31 downto 4)) /= 0 then
                                status_r <= status_invalid_argument;
                                control_state <= make_result;
                            elsif opcode = x"0B" and unsigned(req_data_i(3 downto 0)) > 5 then
                                status_r <= status_unsupported;
                                control_state <= make_result;
                            elsif opcode = x"0B" and
                                  (g_mode_mask(to_integer(unsigned(req_data_i(3 downto 0)))) /= '1' or
                                   advertised_modes_r(to_integer(unsigned(req_data_i(3 downto 0)))) /= '1') then
                                status_r <= status_unsupported;
                                control_state <= make_result;
                            else
                                if opcode = x"0B" then
                                    requested_mode_r <= unsigned(req_data_i(3 downto 0));
                                end if;
                                input_word_r <= req_data_i;
                                lane_count <= 0;
                                control_state <= load_byte;
                            end if;
                        end if;

                    when decode_split =>
                        first_count := to_integer(unsigned(input_word_r(33 downto 24)));
                        split_length_r <= first_count;
                        split_column_r <= unsigned(input_word_r(63 downto 48));
                        split_header_valid_r <= unsigned(input_word_r(23 downto 0)) = 0 and
                                                unsigned(input_word_r(47 downto 34)) = 0 and
                                                first_count /= 0 and first_count < length_r;
                        split_first_end_r <= resize(address_r.column, 17) + to_unsigned(first_count, 17);
                        split_second_sum_r <= resize(unsigned(input_word_r(63 downto 48)), 17) +
                                              to_unsigned(length_r, 17);
                        split_second_limit_r <= to_unsigned(g_page_bytes, 17) + to_unsigned(first_count, 17);
                        control_state <= check_split;

                    when check_split =>
                        if not split_header_valid_r or resize(split_column_r, 17) < split_first_end_r or
                           split_second_sum_r > split_second_limit_r then
                            status_r <= status_invalid_argument;
                            control_state <= drain;
                        else
                            control_state <= load_word;
                        end if;

                    when load_byte =>
                        if transfer_count + 1 = length_r then
                            control_state <= prepare;
                        else
                            transfer_count <= transfer_count + 1;
                            buffer_index_count <= buffer_index_count + 1;
                            if lane_count = 7 then
                                control_state <= load_word;
                            else
                                lane_count <= lane_count + 1;
                            end if;
                        end if;

                    when drain =>
                        if req_data_valid_i = '1' then
                            stored_count <= stored_count - 1;
                            if stored_count = 1 then
                                control_state <= make_result;
                            end if;
                        end if;

                    when prepare =>
                        step_r <= operation_step(x"0" & opcode(3 downto 0), step_index_count);
                        control_state <= configure_phase;

                    when configure_phase =>
                        next_step := step_r;
                        next_phase := zero_phase;
                        byte_count := 0;
                        buffer_index_count <= 0;
                        transfer_count <= 0;
                        lane_count <= 0;
                        if next_step = write_all or next_step = write_first or next_step = write_second then
                            output_word_r <= (others => '0');
                        end if;
                        phase_timer_count <= 0;

                        case next_step is
                            when finished =>
                                if opcode = x"06" and active_mode_r /= 0 then
                                    recovery_timer_count <= 0;
                                    control_state <= recover;
                                else
                                    control_state <= make_result;
                                end if;
                            when address_page | address_page_zero | address_row |
                                 address_column | address_split | address_selector =>
                                next_phase.kind := addr;
                                case next_step is
                                    when address_page =>
                                        next_phase.address := address_r;
                                    when address_page_zero =>
                                        next_phase.address.page := address_r.page;
                                    when address_row =>
                                        next_phase.address_kind := row_address;
                                        next_phase.address.page := address_r.page;
                                    when address_column =>
                                        next_phase.address_kind := column_address;
                                        next_phase.address.column := address_r.column;
                                    when address_split =>
                                        next_phase.address_kind := column_address;
                                        next_phase.address.column := split_column_r;
                                    when others =>
                                        next_phase.address_kind := selector_address;
                                        next_phase.selector := selector_r;
                                end case;
                            when wait_nand =>
                                next_phase.kind := wait_ready;
                            when read_result | read_status_byte | read_parameters | verify_mode =>
                                next_phase.kind := read_data;
                                case next_step is
                                    when read_status_byte => byte_count := 1;
                                    when verify_mode => byte_count := 4;
                                    when read_parameters =>
                                        byte_count := 256;
                                        crc_r <= x"4F4E";
                                        signature_r <= '0';
                                        candidate_features_r <= '0';
                                        candidate_modes_r <= (others => '0');
                                    when others => byte_count := length_r;
                                end case;
                            when write_all | write_first | write_second =>
                                next_phase.kind := write_data;
                                case next_step is
                                    when write_first => byte_count := split_length_r;
                                    when write_second =>
                                        byte_count := length_r - split_length_r;
                                        buffer_index_count <= split_length_r;
                                    when others => byte_count := length_r;
                                end case;
                            when apply_mode =>
                                next_phase.kind := set_timing;
                                next_phase.mode := requested_mode_r;
                            when others =>
                                next_phase.opcode := command_byte(next_step);
                        end case;
                        if next_step /= finished then
                            next_phase.count := to_unsigned(byte_count, 24);
                            phase_length_r <= byte_count;
                            phase_r <= next_phase;
                            control_state <= issue;
                        end if;

                    when issue =>
                        if cmd_ready_i = '1' then
                            case phase_r.kind is
                                when write_data => control_state <= tx_fetch;
                                when read_data => control_state <= rx_take;
                                when others => control_state <= wait_done;
                            end case;
                        end if;

                    when tx_fetch =>
                        control_state <= tx_pack;

                    when tx_pack =>
                        data_byte := ram_read_r;
                        if opcode = x"02" and transfer_count + 1 = phase_length_r then
                            data_byte := data_byte or not req_r.word1(55 downto 48);
                        end if;
                        output_word_r(8 * lane_count + 7 downto 8 * lane_count) <= data_byte;
                        transfer_count <= transfer_count + 1;
                        if transfer_count + 1 < phase_length_r then
                            buffer_index_count <= buffer_index_count + 1;
                        end if;
                        if transfer_count + 1 = phase_length_r then
                            w_last_r <= '1';
                            control_state <= tx_offer;
                        elsif lane_count = 7 then
                            w_last_r <= '0';
                            control_state <= tx_offer;
                        else
                            lane_count <= lane_count + 1;
                            control_state <= tx_fetch;
                        end if;

                    when tx_offer =>
                        if w_ready_i = '1' then
                            if w_last_r = '1' then
                                control_state <= wait_done;
                            else
                                output_word_r <= (others => '0');
                                lane_count <= 0;
                                control_state <= tx_fetch;
                            end if;
                        end if;

                    when rx_take =>
                        if r_valid_i = '1' then
                            expected_last := transfer_count + 8 >= phase_length_r;
                            if (expected_last and r_last_i /= '1') or
                               (not expected_last and r_last_i /= '0') then
                                status_r <= status_internal_error;
                                recovery_timer_count <= 0;
                                control_state <= recover;
                            else
                                input_word_r <= r_data_i;
                                rx_last_word_r <= r_last_i;
                                lane_count <= 0;
                                control_state <= rx_store;
                            end if;
                        end if;

                    when rx_store =>
                        data_byte := ram_data_s;
                        case step_r is
                            when read_status_byte =>
                                nand_status_r <= data_byte;
                            when read_parameters =>
                                if transfer_count < 254 then
                                    crc_r <= crc16_onfi(crc_r, data_byte);
                                elsif transfer_count = 254 then
                                    stored_crc_r(7 downto 0) <= unsigned(data_byte);
                                else
                                    stored_crc_r(15 downto 8) <= unsigned(data_byte);
                                end if;
                                case transfer_count is
                                    when 0 =>
                                        if input_word_r(31 downto 0) = x"49464E4F" then
                                            signature_r <= '1';
                                        end if;
                                    when 8 => candidate_features_r <= data_byte(2);
                                    when 129 => candidate_modes_r <= data_byte(5 downto 0);
                                    when others => null;
                                end case;
                            when others => null;
                        end case;
                        transfer_count <= transfer_count + 1;
                        if transfer_count + 1 = phase_length_r then
                            control_state <= wait_done;
                        else
                            buffer_index_count <= buffer_index_count + 1;
                            if lane_count = 7 then
                                control_state <= rx_take;
                            else
                                lane_count <= lane_count + 1;
                            end if;
                        end if;

                    when wait_done =>
                        if done_valid_i = '1' then
                            if done_i /= phase_ok then
                                if done_i = phase_timeout then
                                    status_r <= status_timeout;
                                else
                                    status_r <= status_internal_error;
                                end if;
                                recovery_timer_count <= 0;
                                control_state <= recover;
                            elsif step_r = verify_mode and
                                  unsigned(input_word_r(31 downto 0)) /= resize(requested_mode_r, 32) then
                                status_r <= status_internal_error;
                                recovery_timer_count <= 0;
                                control_state <= recover;
                            elsif step_r = read_parameters and
                                  (crc_r /= stored_crc_r or signature_r = '0') then
                                if copy_count = 2 then
                                    feature_supported_r <= '0';
                                    advertised_modes_r <= (others => '0');
                                    status_r <= status_internal_error;
                                    control_state <= make_result;
                                else
                                    copy_count <= copy_count + 1;
                                    control_state <= prepare;
                                end if;
                            else
                                case step_r is
                                    when read_status_byte =>
                                        if opcode /= x"07" and nand_status_r(0) = '1' then
                                            status_r <= status_nand_fail;
                                        end if;
                                    when read_result =>
                                        payload_length_r <= length_r;
                                    when read_parameters =>
                                        feature_supported_r <= candidate_features_r;
                                        advertised_modes_r <= candidate_modes_r;
                                        payload_length_r <= length_r;
                                    when verify_mode =>
                                        active_mode_r <= requested_mode_r;
                                    when others => null;
                                end case;
                                step_index_count <= step_index_count + 1;
                                control_state <= prepare;
                            end if;
                        end if;

                    when recover =>
                        payload_length_r <= 0;
                        if recover_ack_i = '1' then
                            active_mode_r <= (others => '0');
                            feature_supported_r <= '0';
                            advertised_modes_r <= (others => '0');
                            recovery_timer_count <= 0;
                            control_state <= recover_release;
                        elsif recovery_timer_count = g_recover_timeout_cycles - 1 then
                            control_state <= fault;
                        else
                            recovery_timer_count <= recovery_timer_count + 1;
                        end if;

                    when recover_release =>
                        if recover_ack_i = '0' then
                            control_state <= make_result;
                        elsif recovery_timer_count = g_recover_timeout_cycles - 1 then
                            control_state <= fault;
                        else
                            recovery_timer_count <= recovery_timer_count + 1;
                        end if;

                    when make_result =>
                        if status_r = status_ok and payload_length_r /= 0 then
                            output_word_r <= (others => '0');
                            buffer_index_count <= 0;
                            transfer_count <= 0;
                            lane_count <= 0;
                            control_state <= rsp_fetch;
                        else
                            payload_length_r <= 0;
                            control_state <= publish;
                        end if;

                    when rsp_fetch =>
                        control_state <= rsp_pack;

                    when rsp_pack =>
                        output_word_r(8 * lane_count + 7 downto 8 * lane_count) <= ram_read_r;
                        transfer_count <= transfer_count + 1;
                        if transfer_count + 1 < payload_length_r then
                            buffer_index_count <= buffer_index_count + 1;
                        end if;
                        if transfer_count + 1 = payload_length_r or lane_count = 7 then
                            control_state <= rsp_offer;
                        else
                            lane_count <= lane_count + 1;
                            control_state <= rsp_fetch;
                        end if;

                    when rsp_offer =>
                        if rsp_data_ready_i = '1' then
                            if transfer_count = payload_length_r then
                                control_state <= publish;
                            else
                                output_word_r <= (others => '0');
                                lane_count <= 0;
                                control_state <= rsp_fetch;
                            end if;
                        end if;

                    when publish =>
                        if rsp_ready_i = '1' then
                            control_state <= select_request;
                        end if;

                    when fault => null;
                end case;
            end if;
        end if;
    end process;
end architecture;
