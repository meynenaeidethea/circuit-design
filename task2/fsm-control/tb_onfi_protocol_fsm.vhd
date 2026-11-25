library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity tb_onfi_protocol_fsm is
end entity;

architecture sim of tb_onfi_protocol_fsm is
    constant period : time := 8 ns;
    constant test_timeout : positive := 1200;
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal initialized : std_logic := '0';
    signal req : request_t := (x"0000000000000000", x"0000000000000000", (others => '0'), '0', (others => '0'), (others => '0'), '0');
    signal req_valid, req_ready : std_logic := '0';
    signal req_data : word_t := (others => '0');
    signal req_data_valid, req_data_ready : std_logic := '0';
    signal rsp : response_t;
    signal rsp_valid, rsp_ready : std_logic := '0';
    signal rsp_data : word_t;
    signal rsp_data_valid, rsp_data_ready : std_logic := '0';
    signal phase : phase_t;
    signal cmd_valid, cmd_ready : std_logic := '0';
    signal w_data, r_data : word_t := (others => '0');
    signal w_valid, w_ready, w_last, r_valid, r_ready, r_last : std_logic := '0';
    signal done : phase_result_t := phase_ok;
    signal done_valid, done_ready, recover_req, recover_ack, busy, fault : std_logic := '0';
    signal phy_count : natural := 0;

    function pack_header(opcode : byte_t; id, length : natural) return word_t is
    begin
        return std_logic_vector(to_unsigned(length, 40)) & std_logic_vector(to_unsigned(id, 16)) & opcode;
    end function;
begin
    clk <= not clk after period / 2;

    dut : entity work.onfi_protocol_fsm
        generic map (
            g_page_bytes => 2048,
            g_pages_per_block => 64,
            g_blocks_per_lun => 1024,
            g_read_id_bytes => 5,
            g_mode_mask => "000011",
            g_phase_timeout_cycles => 1200,
            g_recover_timeout_cycles => 12
        )
        port map (
            clk_i => clk, rst_n_i => rst_n, phy_initialized_i => initialized,
            req_i => req, req_valid_i => req_valid, req_ready_o => req_ready,
            req_data_i => req_data, req_data_valid_i => req_data_valid, req_data_ready_o => req_data_ready,
            rsp_o => rsp, rsp_valid_o => rsp_valid, rsp_ready_i => rsp_ready,
            rsp_data_o => rsp_data, rsp_data_valid_o => rsp_data_valid, rsp_data_ready_i => rsp_data_ready,
            phase_o => phase, cmd_valid_o => cmd_valid, cmd_ready_i => cmd_ready,
            w_data_o => w_data, w_valid_o => w_valid, w_ready_i => w_ready, w_last_o => w_last,
            r_data_i => r_data, r_valid_i => r_valid, r_ready_o => r_ready, r_last_i => r_last,
            done_i => done, done_valid_i => done_valid, done_ready_o => done_ready,
            recover_req_o => recover_req, recover_ack_i => recover_ack, busy_o => busy, fault_o => fault
        );

    process (clk)
        variable cmd_stalled, w_stalled, rsp_stalled, data_stalled : boolean := false;
        variable old_phase : phase_t;
        variable old_rsp : response_t;
        variable old_w, old_data : word_t;
        variable old_last : std_logic;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                cmd_stalled := false;
                w_stalled := false;
                rsp_stalled := false;
                data_stalled := false;
            else
                if cmd_stalled and recover_req = '0' then
                    assert cmd_valid = '1' and phase = old_phase report "Command changed during backpressure" severity failure;
                end if;
                if w_stalled and recover_req = '0' then
                    assert w_valid = '1' and w_data = old_w and w_last = old_last report "PHY write changed under stall" severity failure;
                end if;
                if rsp_stalled then
                    assert rsp_valid = '1' and rsp = old_rsp report "Response descriptor changed under stall" severity failure;
                end if;
                if data_stalled then
                    assert rsp_data_valid = '1' and rsp_data = old_data report "Response word changed under stall" severity failure;
                end if;
                cmd_stalled := cmd_valid = '1' and cmd_ready = '0';
                w_stalled := w_valid = '1' and w_ready = '0';
                rsp_stalled := rsp_valid = '1' and rsp_ready = '0';
                data_stalled := rsp_data_valid = '1' and rsp_data_ready = '0';
                old_phase := phase;
                old_w := w_data;
                old_last := w_last;
                old_rsp := rsp;
                old_data := rsp_data;
                if cmd_valid = '1' and cmd_ready = '1' then
                    phy_count <= phy_count + 1;
                end if;
            end if;
        end if;
    end process;

    process
        type payload_t is array (0 to 12) of word_t;
        variable sent_payload : payload_t := (others => (others => '0'));
        variable stored_payload : payload_t;
        variable id : natural := 0;
        variable last_opcode : byte_t;
        variable last_class : std_logic;
        variable before_count : natural;
        variable page_data : word_t;
        variable page_byte : byte_t;
        variable byte_index : natural;
        variable damaged_header : word_t;

        procedure tick(n : positive := 1) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        procedure wait_high(signal flag : in std_logic; name : string) is
        begin
            for i in 0 to test_timeout + 30 loop
                if flag = '1' then
                    return;
                end if;
                tick;
            end loop;
            assert false report "Timed out waiting for " & name severity failure;
        end procedure;

        procedure request(
            opcode : byte_t;
            length, address : natural := 0;
            mask : byte_t := x"00";
            words, empty : natural := 0;
            frame_error : std_logic := '0';
            read_class : std_logic := '0';
            reserved : boolean := false
        ) is
        begin
            wait_high(req_ready, "req_ready");
            id := id + 1;
            last_opcode := opcode;
            last_class := read_class;
            damaged_header := pack_header(opcode, id, length);
            if reserved then
                damaged_header(34) := '1';
            end if;
            req <= (damaged_header, x"00" & mask & std_logic_vector(to_unsigned(address, 48)),
                    to_unsigned(id, 16), read_class, to_unsigned(words, 7),
                    to_unsigned(empty, 3), frame_error);
            req_valid <= '1';
            tick;
            req_valid <= '0';
        end procedure;

        procedure body_word(value : word_t) is
        begin
            wait_high(req_data_ready, "request body");
            req_data <= value;
            req_data_valid <= '1';
            tick;
            req_data_valid <= '0';
        end procedure;

        procedure take_phase(
            kind : phase_kind_t;
            opcode : byte_t := x"00";
            count : natural := 0;
            column : natural := 0;
            address_kind : address_kind_t := page_address;
            selector : byte_t := x"00";
            page : natural := 0;
            block_index : natural := 0;
            mode : natural := 0
        ) is
        begin
            wait_high(cmd_valid, "cmd_valid");
            assert phase.kind = kind and phase.opcode = opcode and phase.count = count and
                   phase.address_kind = address_kind and phase.address.column = column and
                   phase.address.page.page_in_block = page and phase.address.page.block_index = block_index and
                   phase.address.lun = 0 and phase.selector = selector and phase.mode = mode
                report "Unexpected PHY phase: " & phase_kind_t'image(phase.kind) severity failure;
            tick(2);
            cmd_ready <= '1';
            tick;
            cmd_ready <= '0';
        end procedure;

        procedure complete_phase(result : phase_result_t := phase_ok; delay : positive := 1) is
        begin
            tick(delay);
            done <= result;
            done_valid <= '1';
            wait for 1 ns;
            wait_high(done_ready, "done_ready");
            tick;
            done_valid <= '0';
        end procedure;

        procedure command(value : byte_t) is
        begin
            take_phase(cmd, opcode => value);
            complete_phase;
        end procedure;

        procedure send_read(value : word_t; last : std_logic := '1') is
        begin
            wait_high(r_ready, "r_ready");
            r_valid <= '1';
            r_last <= last;
            r_data <= value;
            tick;
            r_valid <= '0';
        end procedure;

        procedure take_write(value : out word_t; last : std_logic := '1') is
        begin
            wait_high(w_valid, "w_valid");
            tick(3);
            w_ready <= '1';
            wait until rising_edge(clk);
            assert w_valid = '1' and w_last = last report "Unexpected PHY write handshake" severity failure;
            value := w_data;
            wait for 1 ns;
            w_ready <= '0';
        end procedure;

        procedure accept_write(value : word_t; last : std_logic := '1') is
            variable actual : word_t;
        begin
            take_write(actual, last);
            assert actual = value report "Unexpected PHY write data" severity failure;
        end procedure;

        procedure accept_result_data(value : word_t; stalled_cycles : positive := 1) is
        begin
            wait_high(rsp_data_valid, "response body");
            assert rsp_data = value and rsp_valid = '0' report "Unexpected response body or publication order" severity failure;
            tick(stalled_cycles);
            rsp_data_ready <= '1';
            tick;
            rsp_data_ready <= '0';
        end procedure;

        procedure response(status : byte_t; length : natural := 0; nand_status : byte_t := x"00") is
            variable masks : std_logic_vector(15 downto 0) := x"0000";
        begin
            if length /= 0 then
                masks := x"FFFF";
            end if;
            wait_high(rsp_valid, "response descriptor");
            assert rsp.word0 = pack_header(last_opcode, id, length) and
                   rsp.word1 = x"00000000" & masks & nand_status & status and
                   rsp.seq = id and rsp.read_class = last_class and rsp_data_valid = '0'
                report "Unexpected response descriptor at request " & integer'image(id) severity failure;
            tick(3);
            rsp_ready <= '1';
            tick;
            rsp_ready <= '0';
            assert rsp_valid = '0' and busy = '0' report "Result was not retired" severity failure;
        end procedure;

        procedure do_recover is
        begin
            wait_high(recover_req, "recover_req");
            tick(3);
            assert req_ready = '0' and recover_req = '1' severity failure;
            recover_ack <= '1';
            tick;
            assert recover_req = '0' severity failure;
            tick(2);
            assert rsp_valid = '0' and req_ready = '0' severity failure;
            recover_ack <= '0';
            tick;
        end procedure;

        procedure start_read(length : positive; address : natural := 3; column : natural := 3) is
        begin
            request(x"01", length, address, read_class => '1');
            command(x"00");
            take_phase(addr, column => column);
            complete_phase;
            command(x"30");
            take_phase(wait_ready);
            complete_phase(delay => 7);
            take_phase(read_data, count => length);
        end procedure;

        procedure read_status(value : byte_t) is
        begin
            command(x"70");
            take_phase(read_data, count => 1);
            send_read(x"FFFFFFFFFFFFFF" & value);
            complete_phase;
        end procedure;

        procedure parameter_copy(valid_crc : boolean) is
        begin
            take_phase(read_data, count => 256);
            for word_index in 0 to 31 loop
                for lane in 0 to 7 loop
                    byte_index := word_index * 8 + lane;
                    case byte_index is
                        when 0 => page_byte := x"4F";
                        when 1 => page_byte := x"4E";
                        when 2 => page_byte := x"46";
                        when 3 => page_byte := x"49";
                        when 8 => page_byte := x"04";
                        when 129 => page_byte := x"03";
                        when 254 =>
                            page_byte := x"42";
                            if not valid_crc then
                                page_byte := not page_byte;
                            end if;
                        when 255 => page_byte := x"CD";
                        when others => page_byte := x"00";
                    end case;
                    page_data(8 * lane + 7 downto 8 * lane) := page_byte;
                end loop;
                if word_index = 31 then
                    send_read(page_data);
                else
                    send_read(page_data, '0');
                end if;
            end loop;
            complete_phase;
        end procedure;
    begin
        tick(3);
        rst_n <= '1';
        tick;
        assert req_ready = '0' report "Started before PHY initialization" severity failure;
        initialized <= '1';
        tick;

        start_read(9);
        send_read(x"8877665544332211", '0');
        tick(10);
        send_read(x"FFFFFFFFFFFFFF99");
        complete_phase;
        accept_result_data(x"8877665544332211");
        accept_result_data(x"0000000000000099", 9);
        response(status_ok, 9);
        report "PASS READ9: phases, tail and backpressure";

        request(x"02", 9, 3, x"0F", 2, 7);
        body_word(x"8877665544332211");
        tick(12);
        assert cmd_valid = '0' report "WRITE started before full body" severity failure;
        body_word(x"FFFFFFFFFFFFFFAB");
        command(x"80");
        take_phase(addr, column => 3);
        complete_phase;
        take_phase(write_data, count => 9);
        accept_write(x"8877665544332211", '0');
        accept_write(x"00000000000000FB");
        complete_phase;
        command(x"10");
        take_phase(wait_ready);
        complete_phase;
        read_status(x"C1");
        response(status_nand_fail, nand_status => x"C1");
        report "PASS WRITE9: validate, mask and NAND FAIL";

        before_count := phy_count;
        request(x"02", 9, 0, x"FF", 1, 0, '1');
        body_word(x"0000000000000022");
        response(status_bad_packet);
        request(x"02", 1, 0, x"FF", 2, 7, '1');
        body_word(x"0000000000000044");
        body_word(x"0000000000000055");
        response(status_bad_packet);
        request(x"02", 1, 0, x"FF", 1, 6);
        body_word(x"0000000000000066");
        response(status_bad_packet);
        request(x"01", 9, 2040);
        response(status_invalid_argument);
        request(x"01", 513);
        response(status_invalid_argument);
        request(x"12");
        response(status_invalid_opcode);
        request(x"01", 1, reserved => true);
        response(status_bad_packet);
        request(x"09", 10, 3, x"FF", 3, 6);
        body_word(x"0004000003000000");
        body_word(x"8877665544332211");
        body_word(x"000000000000AA99");
        response(status_invalid_argument);
        request(x"0B", 4, 1, words => 1, empty => 4);
        body_word(x"0000000000000001");
        response(status_unsupported);
        assert phy_count = before_count and cmd_valid = '0' report "Invalid request accessed the PHY" severity failure;
        report "PASS invalid packets: drain, length, boundary, reserved, opcode and unsupported";

        request(x"03", 4, 32, read_class => '1');
        command(x"90");
        take_phase(addr, address_kind => selector_address, selector => x"20");
        complete_phase;
        take_phase(read_data, count => 4);
        send_read(x"FFFFFFFF49464E4F");
        complete_phase;
        accept_result_data(x"0000000049464E4F");
        response(status_ok, 4);

        request(x"04", 4, read_class => '1');
        command(x"EC");
        take_phase(addr, address_kind => selector_address);
        complete_phase;
        take_phase(wait_ready);
        complete_phase;
        parameter_copy(false);
        parameter_copy(true);
        accept_result_data(x"0000000049464E4F");
        response(status_ok, 4);

        request(x"05", address => 131072);
        command(x"60");
        take_phase(addr, address_kind => row_address, block_index => 1);
        complete_phase;
        command(x"D0");
        take_phase(wait_ready);
        complete_phase;
        read_status(x"C0");
        response(status_ok, nand_status => x"C0");

        request(x"07");
        read_status(x"C1");
        response(status_ok, nand_status => x"C1");

        request(x"08", 1, 2050, read_class => '1');
        command(x"00");
        take_phase(addr, page => 1);
        complete_phase;
        command(x"30");
        take_phase(wait_ready);
        complete_phase;
        command(x"05");
        take_phase(addr, column => 2, address_kind => column_address);
        complete_phase;
        command(x"E0");
        take_phase(read_data, count => 1);
        send_read(x"00000000000000D4");
        complete_phase;
        accept_result_data(x"00000000000000D4");
        response(status_ok, 1);

        request(x"09", 10, 3, x"FF", 3, 6);
        body_word(x"0014000003000000");
        body_word(x"8877665544332211");
        body_word(x"FFFFFFFFFFFFAA99");
        command(x"80");
        take_phase(addr, column => 3);
        complete_phase;
        take_phase(write_data, count => 3);
        accept_write(x"0000000000332211");
        complete_phase;
        command(x"85");
        take_phase(addr, address_kind => column_address, column => 20);
        complete_phase;
        take_phase(write_data, count => 7);
        accept_write(x"00AA998877665544");
        complete_phase;
        command(x"10");
        take_phase(wait_ready);
        complete_phase;
        read_status(x"C0");
        response(status_ok, nand_status => x"C0");

        request(x"0A", 4, 1, read_class => '1');
        command(x"EE");
        take_phase(addr, address_kind => selector_address, selector => x"01");
        complete_phase;
        take_phase(wait_ready);
        complete_phase;
        take_phase(read_data, count => 4);
        send_read(x"FFFFFFFF00000000");
        complete_phase;
        accept_result_data(x"0000000000000000");
        response(status_ok, 4);

        request(x"0B", 4, 1, words => 1, empty => 4);
        body_word(x"FFFFFFFF00000001");
        command(x"EF");
        take_phase(addr, address_kind => selector_address, selector => x"01");
        complete_phase;
        take_phase(write_data, count => 4);
        accept_write(x"0000000000000001");
        complete_phase;
        take_phase(set_timing, mode => 1);
        complete_phase;
        command(x"EE");
        take_phase(addr, address_kind => selector_address, selector => x"01");
        complete_phase;
        take_phase(wait_ready);
        complete_phase;
        take_phase(read_data, count => 4);
        send_read(x"0000000000000001");
        complete_phase;
        response(status_ok);

        request(x"06");
        command(x"FF");
        take_phase(wait_ready);
        complete_phase;
        do_recover;
        response(status_ok);
        report "PASS operations 03..0B: CRC fallback, split, modes and reset";

        for byte_index in 0 to 99 loop
            sent_payload(byte_index / 8)(8 * (byte_index mod 8) + 7 downto 8 * (byte_index mod 8)) :=
                std_logic_vector(to_unsigned(byte_index + 1, 8));
        end loop;
        request(x"02", 100, 3, x"FF", 13, 4);
        for i in sent_payload'range loop
            body_word(sent_payload(i));
        end loop;
        command(x"80");
        take_phase(addr, column => 3);
        complete_phase;
        take_phase(write_data, count => 100);
        for i in stored_payload'range loop
            if i = stored_payload'high then
                take_write(stored_payload(i));
            else
                take_write(stored_payload(i), '0');
            end if;
        end loop;
        assert stored_payload = sent_payload report "WRITE100 data changed before reaching PHY" severity failure;
        complete_phase;
        command(x"10");
        take_phase(wait_ready);
        complete_phase;
        read_status(x"C0");
        response(status_ok, nand_status => x"C0");

        start_read(100);
        for i in stored_payload'range loop
            if i = stored_payload'high then
                send_read(stored_payload(i));
            else
                send_read(stored_payload(i), '0');
            end if;
        end loop;
        complete_phase;
        for i in sent_payload'range loop
            accept_result_data(sent_payload(i), 4);
        end loop;
        response(status_ok, 100);
        report "PASS WRITE100 -> READ100: all bytes, 13 words and zero tail padding";

        start_read(512, 0, 0);
        for i in 0 to 63 loop
            if i = 63 then
                send_read(std_logic_vector(to_unsigned(i + 217, 64)));
            else
                send_read(std_logic_vector(to_unsigned(i + 217, 64)), '0');
            end if;
        end loop;
        complete_phase;
        for i in 0 to 63 loop
            accept_result_data(std_logic_vector(to_unsigned(i + 217, 64)));
        end loop;
        response(status_ok, 512);
        report "PASS maximum length, address and buffer counters";

        start_read(9);
        send_read(x"0000000000000000", '1');
        do_recover;
        response(status_internal_error);

        start_read(9);
        complete_phase;
        do_recover;
        response(status_internal_error);

        start_read(1);
        send_read(x"0000000000000001");
        r_valid <= '1';
        tick;
        r_valid <= '0';
        do_recover;
        response(status_internal_error);

        start_read(9);
        send_read(x"8877665544332211", '0');
        complete_phase(phase_io_error);
        do_recover;
        response(status_internal_error);

        request(x"06");
        command(x"FF");
        take_phase(wait_ready);
        do_recover;
        response(status_timeout);

        start_read(9);
        send_read(x"8877665544332211", '0');
        rst_n <= '0';
        tick;
        assert r_ready = '0' and rsp_valid = '0' and busy = '0' severity failure;
        rst_n <= '1';
        tick;
        request(x"07");
        read_status(x"C0");
        response(status_ok, nand_status => x"C0");

        start_read(9);
        send_read(x"0000000000000000");
        wait_high(recover_req, "recovery before fault");
        tick(13);
        assert fault = '1' and req_ready = '0' and rsp_valid = '0' severity failure;
        rst_n <= '0';
        tick;
        rst_n <= '1';
        tick;
        assert fault = '0' and req_ready = '1' severity failure;
        report "PASS bad PHY streams, early done, timeout, recovery, reset and fault";
        std.env.finish;
        wait;
    end process;
end architecture;
