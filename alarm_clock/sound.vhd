-- Playing sound

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity sound is
	generic (
		hz: positive := master_clock_hz; -- main system clock frequency
		tone_hz: positive := 880; -- tone frequency
		pulse_ms: positive := 100; -- period of pulses (ms, half tone, half silence)
		batch_len: positive := 4 -- pulses in a batch
	);
	port (
		Clk: in std_logic; -- the main system clock (edge)
		Play: in std_logic; -- whether to play sound (level)
		Speaker: out std_logic -- speaker output
	);
end entity;

architecture main of sound is
	signal Rst, Tone, Pulse, Batch: std_logic;
	signal state: std_logic_vector(0 to 1) := "00";
	signal edge: boolean;
begin
	edge <= state(0) = '1' and state(1) = '0';
	process (Clk) is
	begin
		if rising_edge(Clk) then
			if edge then
				Rst <= '1';
			else
				Rst <= '0';
			end if;
			state(1) <= state(0);
			state(0) <= Play;
		end if;
	end process;
	tone_gen: entity work.waveform
		generic map (period=>master_clock_hz/2/tone_hz, use_i=>false)
		port map (Clk=>Clk, Rst=>'0', I=>'0', O=>Tone);
	pulse_gen: entity work.waveform
		generic map (period=>master_clock_hz/2/1000*pulse_ms, use_i=>false)
		port map (Clk=>Clk, Rst=>Rst, I=>'0', O=>Pulse);
	batch_gen: entity work.waveform
		generic map (period=>2*batch_len, use_i=>true)
		port map (Clk=>Clk, Rst=>Rst, I=>Pulse, O=>Batch);
	Speaker <= not (Play and Tone and Pulse and Batch);
end;