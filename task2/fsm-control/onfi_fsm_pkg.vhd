library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package onfi_fsm_pkg is
    subtype byte_t is std_logic_vector(7 downto 0);
    subtype word_t is std_logic_vector(63 downto 0);

    type request_t is record
        word0 : word_t;
        word1 : word_t;
        seq : unsigned(15 downto 0);
        read_class : std_logic;
        body_words : unsigned(6 downto 0);
        tail_empty : unsigned(2 downto 0);
        frame_error : std_logic;
    end record;

    type response_t is record
        word0 : word_t;
        word1 : word_t;
        seq : unsigned(15 downto 0);
        read_class : std_logic;
    end record;

    type nand_page_t is record
        block_index : unsigned(23 downto 0);
        page_in_block : unsigned(15 downto 0);
    end record;

    type nand_address_t is record
        lun : unsigned(7 downto 0);
        page : nand_page_t;
        column : unsigned(15 downto 0);
    end record;

    type phase_kind_t is (cmd, addr, write_data, read_data, wait_ready, set_timing);
    type address_kind_t is (page_address, row_address, column_address, selector_address);
    type phase_result_t is (phase_ok, phase_io_error, phase_timeout);

    type phase_t is record
        kind : phase_kind_t;
        opcode : byte_t;
        address : nand_address_t;
        address_kind : address_kind_t;
        selector : byte_t;
        count : unsigned(23 downto 0);
        mode : unsigned(3 downto 0);
    end record;

    constant zero_address : nand_address_t := (
        lun => (others => '0'),
        page => (block_index => (others => '0'), page_in_block => (others => '0')),
        column => (others => '0')
    );
    constant zero_phase : phase_t := (
        cmd, x"00", zero_address, page_address, x"00", (others => '0'), (others => '0')
    );
    constant status_ok : byte_t := x"00";
    constant status_invalid_opcode : byte_t := x"01";
    constant status_bad_packet : byte_t := x"02";
    constant status_invalid_argument : byte_t := x"03";
    constant status_unsupported : byte_t := x"04";
    constant status_nand_fail : byte_t := x"05";
    constant status_timeout : byte_t := x"06";
    constant status_internal_error : byte_t := x"07";

    type step_t is (
        finished, c00, c30, c80, c10, c90, cec, c60, cd0, cff, c70,
        c05, ce0, c85, cee, cef, address_page, address_page_zero,
        address_row, address_column, address_split, address_selector,
        wait_nand, read_result, read_status_byte, read_parameters,
        write_all, write_first, write_second, apply_mode, verify_mode
    );
    function operation_step(opcode : byte_t; index : natural) return step_t;
    function command_byte(step : step_t) return byte_t;
    function crc16_onfi(crc : unsigned(15 downto 0); data : byte_t) return unsigned;
    function power_of_two(value : positive) return boolean;
end package;

package body onfi_fsm_pkg is
    type script_t is array (natural range <>) of step_t;
    type operation_table_t is array (1 to 11) of script_t(0 to 9);
    constant scripts : operation_table_t := (
        (c00, address_page, c30, wait_nand, read_result, others => finished),
        (c80, address_page, write_all, c10, wait_nand, c70, read_status_byte, others => finished),
        (c90, address_selector, read_result, others => finished),
        (cec, address_selector, wait_nand, read_parameters, others => finished),
        (c60, address_row, cd0, wait_nand, c70, read_status_byte, others => finished),
        (cff, wait_nand, others => finished),
        (c70, read_status_byte, others => finished),
        (c00, address_page_zero, c30, wait_nand, c05, address_column, ce0, read_result, others => finished),
        (c80, address_page, write_first, c85, address_split, write_second, c10, wait_nand, c70, read_status_byte),
        (cee, address_selector, wait_nand, read_result, others => finished),
        (cef, address_selector, write_all, apply_mode, cee, address_selector, wait_nand, verify_mode, others => finished)
    );

    function operation_step(opcode : byte_t; index : natural) return step_t is
        constant operation : natural := to_integer(unsigned(opcode));
    begin
        if operation >= scripts'low and operation <= scripts'high and index <= 9 then
            return scripts(operation)(index);
        end if;
        return finished;
    end function;

    function command_byte(step : step_t) return byte_t is
    begin
        case step is
            when c00 => return x"00";
            when c30 => return x"30";
            when c80 => return x"80";
            when c10 => return x"10";
            when c90 => return x"90";
            when cec => return x"EC";
            when c60 => return x"60";
            when cd0 => return x"D0";
            when cff => return x"FF";
            when c70 => return x"70";
            when c05 => return x"05";
            when ce0 => return x"E0";
            when c85 => return x"85";
            when cee => return x"EE";
            when cef => return x"EF";
            when others => return x"00";
        end case;
    end function;

    function crc16_onfi(crc : unsigned(15 downto 0); data : byte_t) return unsigned is
        variable result : unsigned(15 downto 0) := crc;
    begin
        for bit_index in 7 downto 0 loop
            if (result(15) xor data(bit_index)) = '1' then
                result := shift_left(result, 1) xor x"8005";
            else
                result := shift_left(result, 1);
            end if;
        end loop;
        return result;
    end function;

    function power_of_two(value : positive) return boolean is
        constant bits : unsigned(31 downto 0) := to_unsigned(value, 32);
    begin
        return (bits and (bits - 1)) = 0;
    end function;
end package body;
