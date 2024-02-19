-- Reading data from an infrared receiver

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_infrared is
	component infrared is
		generic (
			-- IR sensor uses inverted logic ('0' for logical 1)
			inverted: boolean := true
		);
		port (
			-- the master system clock
			Clk: in std_logic;
			-- reset
			Rst: in std_logic;
			-- IR sensor
			IR: in std_logic;
			-- data read by a reader (resets MA, CA)
			Ack: in std_logic;
			-- message available (set when IR message is received or an error occurred)
			MA: out std_logic;
			-- new count available (set when a new repeat code is received and Cnt is incremented)
			CA: out std_logic;
			-- error flag; if set something was received, but Addr, Cmd, or Cnt is invalid
			Err: out std_logic;
			-- first (address) byte of a received message
			Addr: out unsigned(7 downto 0);
			-- second (command) byte of a received message
			Cmd: out unsigned(7 downto 0);
			-- repetition counter; starts at 0 when a message is received, incremented by each repeat code
			-- more than 255 repetiotions are reported as 255
			Cnt: out unsigned(7 downto 0);
			-- debugging signals
			DBG: out std_logic_vector(1 to 4)
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_io;
use lib_io.pkg_crystal.crystal_hz;

entity infrared is
	generic (
		inverted: boolean
	);
	port (
		Clk, Rst, IR, Ack: in std_logic;
		MA, CA, Err: out std_logic;
		Addr, Cmd, Cnt: out unsigned(7 downto 0);
		DBG: out std_logic_vector(1 to 4) := "0000"
	);
end entity;

architecture main of infrared is
	constant cnt_max: unsigned(Cnt'range) := (others=>'1');
	signal msg_addr, msg_cmd: unsigned(7 downto 0);
	signal msg, repeat, error: std_logic;
begin
	-- I/O port FSM
	io_fsm: block is
		type state_t is (Init, Ready, Message);
		signal state: state_t := Init;
	begin
		step: process(Clk, Rst) is
			procedure ack_err_msg(constant test_repeat: boolean) is
			begin
				if Ack = '1' then
					MA <= '0';
					CA <= '0';
				end if;
				if error = '1' or (repeat = '1' and test_repeat) then
					MA <= '1';
					CA <= '0';
					Err <= '1';
					Addr <= (others =>'0');
					Cmd <= (others=>'0');
					Cnt <= (others=>'0');
				elsif msg = '1' then
					MA <= '1';
					CA <= '0';
					Err <= '0';
					Addr <= msg_addr;
					Cmd <= msg_cmd;
					Cnt <= (others=>'0');
				end if;
			end procedure;
		begin
			if Rst = '1' then
				state <= Init;
			elsif rising_edge(Clk) then
				case state is
					when Init =>
						MA <= '0';
						CA <= '0';
						Err <= '0';
						Addr <= (others=>'0');
						Cmd <= (others=>'0');
						Cnt <= (others=>'0');
						state <= Ready;
					when Ready =>
						ack_err_msg(true);
						if error /= '1' and repeat /= '1' and msg = '1' then
							state <= Message;
						end if;
					when Message =>
						ack_err_msg(false);
						if err = '1' then
							state <= Ready;
						elsif msg /= '1' and repeat = '1' then
							Err <= '0';
							if Cnt < cnt_max then
								CA <= '1';
								Cnt <= Cnt + 1;
							end if;
						end if;
					when others =>
						null;
				end case;
			end if;
		end process;		
	end block;
	
	-- NEC IR protocol FSM
	nec_ir_fsm: block is
		type state_t is (Init, Start1, Start0, Bit1, Bit0, Final1, Repeat1);
		signal state: state_t := Init;
		signal ir_sync, ir_val, ir_prev: std_logic := '0';
	begin
		ir_sync <= not IR when inverted else IR;
		step: process(Clk, Rst) is
			constant period_us: natural := crystal_hz / 1_000_000; -- Clk ticks in 1 us
			constant period_basic: natural := period_us * 562 + period_us / 2; -- 562.5 us
			constant period_init1: natural := period_basic * 16; -- initial pulse, 9000 us
			constant period_init0: natural := period_basic * 8; -- initial space, 4500 us
			constant period_zero: natural := period_basic; -- logical 0, 562.5 us
			constant period_one: natural := period_basic * 3; -- logical 1, 1687.5 us
			constant period_repeat: natural := period_basic * 4; -- repeat code space, 2250 us
			constant delta: natural := period_basic / 4; -- allowed timing error, 140.625 us
			subtype timer_t is natural range 0 to period_init1 + delta;
			variable timer: timer_t;
			type data_t is array(0 to 3) of unsigned(7 downto 0);
			variable data: data_t;
			variable i_data: natural range 0 to 3;
			variable i_bit: natural range 0 to 7;
			variable has_bit: boolean;
			variable bit_val: std_logic;
			variable DBG_STATE: std_logic_vector(1 to 4) := "0000";
		begin
			if Rst = '1' then
				state <= Init;
			elsif rising_edge(Clk) then
				ir_val <= ir_sync;
				ir_prev <= ir_val;
				msg <= '0';
				repeat <= '0';
				error <= '0';
				timer := timer + 1;
				DBG_STATE(4) := ir_val;
				case state is
					when Init =>
						if ir_val = '1' and ir_prev = '0' then
							timer := 0;
							state <= Start1;
						end if;
					when Start1 =>
						if ir_val = '0' then
							if timer > period_init1 - delta and timer < period_init1 + delta then
								timer := 0;
								state <= Start0;
							else
								error <= '1';
								state <= Init;
							end if;
						elsif timer >= period_init1 + delta and timer >= period_repeat + delta then
							error <= '1';
							state <= Init;
						end if;
					when Start0 =>
						if ir_val = '1' then
							if timer > period_init0 - delta and timer < period_init0 + delta then
								timer := 0;
								i_data := 0;
								i_bit := 0;
								state <= Bit1;
							elsif timer > period_repeat - delta and timer < period_repeat + delta then
								timer := 0;
								state <= Repeat1;
							else
								error <= '1';
								state <= Init;
							end if;
						elsif timer >= period_init0 + delta then
							error <= '1';
							state <= Init;
						end if;
					when Bit1 =>
						if ir_val = '0' then
							if timer > period_basic - delta and timer < period_basic + delta then
								timer := 0;
								state <= Bit0;
							else
								error <= '1';
								state <= Init;
							end if;
						elsif timer >= period_basic + delta then
							error <= '1';
							state <= Init;
						end if;
					when Bit0 =>
						has_bit := false;
						if ir_val = '1' then
							if timer > period_zero - delta and timer < period_zero + delta then
								has_bit := true;
								bit_val := '0';
							elsif timer > period_one - delta and timer < period_one + delta then
								has_bit := true;
								bit_val := '1';
							else
								error <= '1';
								state <= Init;
							end if;
						elsif timer >= period_zero + delta and timer >= period_one + delta then
							error <= '1';
							state <= Init;
						end if;
						if has_bit then
							timer := 0;
							state <= Bit1;
							data(i_data)(i_bit) := bit_val;
							if i_bit < 7 then
								i_bit := i_bit + 1;
							elsif i_data < 3 then
								i_data := i_data + 1;
								i_bit := 0;
							else
								state <= Final1;
							end if;
						end if;
					when Final1 =>
						if ir_val = '0' then
							if timer > period_basic - delta and timer < period_basic + delta then
								if data(0) = (not data(1)) and data(2) = (not data(3)) then
									msg_addr <= data(0);
									msg_cmd <= data(2);
									msg <= '1';
								else
									error <= '1';
								end if;
							else
								error <= '1';
							end if;
							state <= Init;
						elsif timer >= period_basic + delta then
							error <= '1';
							state <= Init;
						end if;
					when Repeat1 =>
						if ir_val = '0' then
							if timer > period_basic - delta and timer < period_basic + delta then
								repeat <= '1';
							else
								error <= '1';
							end if;
							state <= Init;
						elsif timer >= period_basic + delta then
							error <= '1';
							state <= Init;
						end if;
					when others =>
						null;
				end case;
				DBG <= DBG_STATE;
			end if;
		end process;
	end block;
end architecture;