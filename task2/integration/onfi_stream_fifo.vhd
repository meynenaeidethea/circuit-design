library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

entity onfi_stream_fifo is
    port (
        rst_ni : in std_logic;
        write_clk_i, read_clk_i : in std_logic;
        write_up_i, read_up_i : in std_logic;
        write_data_i : in std_logic_vector(68 downto 0);
        write_valid_i : in std_logic;
        write_ready_o : out std_logic;
        read_data_o : out std_logic_vector(68 downto 0);
        read_valid_o : out std_logic;
        read_ready_i : in std_logic
    );
end entity;

architecture rtl of onfi_stream_fifo is
    signal full_s, empty_s : std_logic;
    signal push_s, pop_s : std_logic;
begin
    write_ready_o <= write_up_i and not full_s;
    read_valid_o <= read_up_i and not empty_s;
    push_s <= write_valid_i and write_ready_o;
    pop_s <= read_valid_o and read_ready_i;

    fifo : dcfifo
        generic map (
            intended_device_family => "Cyclone 10 LP",
            lpm_numwords => 128,
            lpm_width => 69,
            lpm_widthu => 7,
            lpm_showahead => "ON",
            clocks_are_synchronized => "FALSE",
            rdsync_delaypipe => 4,
            wrsync_delaypipe => 4,
            read_aclr_synch => "ON",
            write_aclr_synch => "ON"
        )
        port map (
            aclr => not rst_ni, data => write_data_i, q => read_data_o,
            wrclk => write_clk_i, rdclk => read_clk_i,
            wrreq => push_s, rdreq => pop_s, wrfull => full_s, rdempty => empty_s,
            eccstatus => open, rdfull => open, rdusedw => open,
            wrempty => open, wrusedw => open
        );
end architecture;
