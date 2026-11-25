library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.onfi_fsm_pkg.all;

entity tb_onfi_async_phy is
    port (
        clk_i, rst_ni : in std_logic;
        initialized_o : out std_logic := '0';
        phase_i : in phase_t;
        cmd_valid_i : in std_logic;
        cmd_ready_o : out std_logic := '0';
        w_data_i : in word_t;
        w_last_i, w_valid_i : in std_logic;
        w_ready_o : out std_logic := '0';
        r_data_o : out word_t;
        r_last_o : out std_logic := '0';
        r_valid_o : out std_logic := '0';
        r_ready_i : in std_logic;
        done_o : out phase_result_t := phase_ok;
        done_valid_o : out std_logic := '0';
        done_ready_i : in std_logic;
        recover_req_i : in std_logic;
        recover_ack_o : out std_logic := '0';
        ce_no, re_no, we_no : out std_logic := '1';
        cle_o, ale_o : out std_logic := '0';
        rb_ni : in std_logic;
        dq_io : inout byte_t := (others => 'Z')
    );
end entity;

architecture sim of tb_onfi_async_phy is
    function bytes_in_word(count : positive) return positive is
    begin
        if count < 8 then
            return count;
        end if;
        return 8;
    end function;
begin
    process
        variable phase_v : phase_t;
        variable row_v, column_v : unsigned(15 downto 0);
        variable pending_count : natural;
        variable word_v : word_t;
        variable byte_v : byte_t;

        procedure write_byte(data : byte_t; cle, ale : std_logic) is
        begin
            cle_o <= cle;
            ale_o <= ale;
            dq_io <= data;
            wait for 80 ns;
            we_no <= '0';
            wait for 64 ns;
            we_no <= '1';
            wait for 64 ns;
            dq_io <= (others => 'Z');
            cle_o <= '0';
            ale_o <= '0';
        end procedure;

        procedure read_byte(data : out byte_t) is
        begin
            dq_io <= (others => 'Z');
            wait for 128 ns;
            re_no <= '0';
            wait for 64 ns;
            data := to_x01(dq_io);
            assert not is_x(data) report "NAND data bus is not driven during RE#" severity failure;
            re_no <= '1';
            wait for 144 ns;
        end procedure;

        procedure await_nand is
        begin
            wait for 256 ns;
            if to_x01(rb_ni) /= '1' then
                wait until to_x01(rb_ni) = '1' for 2 ms;
            end if;
            assert to_x01(rb_ni) = '1' report "NAND did not release R/B#" severity failure;
        end procedure;
    begin
        loop
            initialized_o <= '0';
            cmd_ready_o <= '0';
            done_valid_o <= '0';
            ce_no <= '1';
            if rst_ni /= '1' then
                wait until rst_ni = '1';
            end if;
            if now < 1100 us then
                wait for 1100 us - now;
            end if;
            ce_no <= '0';
            write_byte(x"FF", '1', '0');
            await_nand;
            wait until rising_edge(clk_i);
            initialized_o <= '1';
            cmd_ready_o <= '1';
            loop
                wait until rising_edge(clk_i) or rst_ni = '0';
                exit when rst_ni = '0';
                if recover_req_i = '1' then
                    cmd_ready_o <= '0';
                    write_byte(x"FF", '1', '0');
                    await_nand;
                    wait until rising_edge(clk_i);
                    recover_ack_o <= '1';
                    wait until recover_req_i = '0' or rst_ni = '0';
                    recover_ack_o <= '0';
                    exit when rst_ni = '0';
                    cmd_ready_o <= '1';
                elsif cmd_valid_i = '1' then
                    phase_v := phase_i;
                    cmd_ready_o <= '0';
                    done_o <= phase_ok;
                    case phase_v.kind is
                        when cmd =>
                            write_byte(phase_v.opcode, '1', '0');
                        when addr =>
                            column_v := phase_v.address.column;
                            row_v := shift_left(resize(phase_v.address.page.block_index, 16), 6) or
                                     resize(phase_v.address.page.page_in_block, 16);
                            if phase_v.address_kind = selector_address then
                                write_byte(phase_v.selector, '0', '1');
                            else
                                if phase_v.address_kind /= row_address then
                                    write_byte(std_logic_vector(column_v(7 downto 0)), '0', '1');
                                    write_byte(std_logic_vector(column_v(15 downto 8)), '0', '1');
                                end if;
                                if phase_v.address_kind /= column_address then
                                    write_byte(std_logic_vector(row_v(7 downto 0)), '0', '1');
                                    write_byte(std_logic_vector(row_v(15 downto 8)), '0', '1');
                                end if;
                            end if;
                            wait for 240 ns;
                        when write_data =>
                            pending_count := to_integer(phase_v.count);
                            while pending_count > 0 loop
                                w_ready_o <= '1';
                                wait until rising_edge(clk_i) and w_valid_i = '1';
                                word_v := w_data_i;
                                assert (w_last_i = '1') = (pending_count <= 8)
                                    report "Wrong final write word" severity failure;
                                w_ready_o <= '0';
                                for lane in 0 to bytes_in_word(pending_count) - 1 loop
                                    write_byte(word_v(lane * 8 + 7 downto lane * 8), '0', '0');
                                end loop;
                                pending_count := pending_count - bytes_in_word(pending_count);
                            end loop;
                        when read_data =>
                            pending_count := to_integer(phase_v.count);
                            while pending_count > 0 loop
                                word_v := (others => '0');
                                for lane in 0 to bytes_in_word(pending_count) - 1 loop
                                    read_byte(byte_v);
                                    word_v(lane * 8 + 7 downto lane * 8) := byte_v;
                                end loop;
                                wait until rising_edge(clk_i);
                                r_data_o <= word_v;
                                if pending_count <= 8 then
                                    r_last_o <= '1';
                                else
                                    r_last_o <= '0';
                                end if;
                                r_valid_o <= '1';
                                wait until rising_edge(clk_i) and r_ready_i = '1';
                                r_valid_o <= '0';
                                pending_count := pending_count - bytes_in_word(pending_count);
                            end loop;
                        when wait_ready =>
                            await_nand;
                        when set_timing =>
                            done_o <= phase_io_error;
                    end case;
                    wait until rising_edge(clk_i);
                    done_valid_o <= '1';
                    wait until rising_edge(clk_i) and done_ready_i = '1';
                    done_valid_o <= '0';
                    cmd_ready_o <= '1';
                end if;
            end loop;
        end loop;
    end process;
end architecture;
