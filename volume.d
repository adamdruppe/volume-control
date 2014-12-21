/**
	A simple terminal-based volume control with
	keyboard and mouse control.

	Compile:
	dmd volume.d terminal.d simpleaudio.d eventloop.d -version=with_eventloop
*/

import terminal;
import arsd.simpleaudio;
import arsd.eventloop;

/// Args: numeric means set it to that percent
///       mute means mute. unmute too.
///
///       +xx or -xx means relative adjustment.
///
///  Run without arguments for interactive mode.
// FIXME: make those args work lol
void main(string[] args) {
	auto mixer = AudioMixer(0);
	auto terminal = Terminal(ConsoleOutputType.cellular);
	terminal.hideCursor();
	auto input = RealTimeConsoleInput(&terminal, ConsoleInputFlags.raw | ConsoleInputFlags.allInputEvents);

	void redraw() {
		terminal.moveTo(3, terminal.height - 3);
		auto total = terminal.width - 8;
		auto volume = mixer.getMasterVolume();
		foreach(i; 0 .. total * volume / 100)
			terminal.write("=");
		foreach(i; total * volume / 100 .. total)
			terminal.write(" ");
		terminal.writef(" %3d", volume);
		terminal.flush();
	}

	void relativeVolumeAdjustment(in int change) {
		assert(change);

		auto vol = mixer.getMasterVolumeExact();
		const original = vol;

		vol += change;

		if(vol < mixer.minVolume) vol = mixer.minVolume;
		if(vol > mixer.maxVolume) vol = mixer.maxVolume;

		if(original == vol)
			return;

		mixer.setMasterVolumeExact(vol);
		redraw();
	}

	void handleTerminalInput(InputEvent ev) {
		switch(ev.type) {
			case InputEvent.Type.CharacterEvent:
				auto event = ev.get!(InputEvent.Type.CharacterEvent);
				switch(event.character) {
					case 'm':
						mixer.muteMaster = !mixer.muteMaster;
						redraw();
					break;
					case '0': .. case '9':
						mixer.setMasterVolume((event.character - '0') * 10);
						redraw();
					break;
					case '-':
						relativeVolumeAdjustment(-1);
					break;
					case '+':
						relativeVolumeAdjustment(1);
					break;
					default:
						// intentionally left blank
				}
				// mute and jumping around
			break;
			case InputEvent.Type.NonCharacterKeyEvent:
				auto event = ev.get!(InputEvent.Type.NonCharacterKeyEvent);
				// arrows and page and home
				switch(event.key) {
					case NonCharacterKeyEvent.Key.UpArrow:
						relativeVolumeAdjustment(1);
					break;
					case NonCharacterKeyEvent.Key.DownArrow:
						relativeVolumeAdjustment(-1);
					break;
					case NonCharacterKeyEvent.Key.PageUp:
						relativeVolumeAdjustment(10 * mixer.maxVolume / 100);
					break;
					case NonCharacterKeyEvent.Key.PageDown:
						relativeVolumeAdjustment(-10 * mixer.maxVolume / 100);
					break;
					case NonCharacterKeyEvent.Key.Home:
						// mixer.setMasterVolume(100);
						// redraw();
						// that's liable to just hurt my ears!
					break;
					case NonCharacterKeyEvent.Key.End:
						mixer.setMasterVolume(0);
						redraw();
					break;
					case NonCharacterKeyEvent.Key.escape:
						exit();
					break;
					default:
						// nothing needed
				}
			break;
			case InputEvent.Type.SizeChangedEvent:
				// fix the UI
				redraw();
			break;
			case InputEvent.Type.MouseEvent:
				auto event = ev.get!(InputEvent.Type.MouseEvent);
				// handle wheels and clicks

				if(event.eventType == MouseEvent.Type.Pressed) {
					if(event.buttons & MouseEvent.Button.ScrollUp)
						relativeVolumeAdjustment(1);
					else if(event.buttons & MouseEvent.Button.ScrollDown)
						relativeVolumeAdjustment(-1);
				}
			break;
			case InputEvent.Type.UserInterruptionEvent:
			case InputEvent.Type.HangupEvent:
				exit();
			break;
			default: /* ignore */
		}
	}

	addListener(&handleTerminalInput);

	void handleMixerChange(AudioMixer.MixerEvent ev) {
		redraw();
	}

	addListener(&handleMixerChange);

	redraw();

	loop();
}
