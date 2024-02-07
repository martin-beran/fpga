-- Playing sound

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity sound is
	generic (
		hz: positive := master_clock_hz; -- main system clock frequency
		tone_hz: positive := 880; -- tone frequency
		pulse_ms: positive := 100; -- period of pulses (ms, half tone, half silence)
		batch_len: positive := 4; -- pulses in a batch
		batches: positive := 75 -- play this number of batches (1 minute)
	);
	port (
		Clk: in std_logic; -- the main system clock (edge)
		Play: in std_logic; -- whether to play sound (level)
		Speaker: out std_logic -- speaker output
	);
end entity;

architecture main of sound is
	signal Rst, Tone, Pulse, Batch, Silence: std_logic;
begin
	process (Clk) is
		variable b: natural;
		variable prev_play, prev_batch: std_logic := '0';
	begin
		if rising_edge(Clk) then
			Silence <= '0';
			if Play = '1' and prev_play = '0' then
				Rst <= '1';
				b:= 0;
			else
				Rst <= '0';
				if b < batches and Batch = '0' and prev_batch = '1' then
					b := b + 1;
				elsif b = batches then
					Silence <= '1';
				end if;
			end if;
			prev_play := Play;
			prev_batch := Batch;
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
	Speaker <= not (Play and Tone and Pulse and Batch and not Silence);
end;