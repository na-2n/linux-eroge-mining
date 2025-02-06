# Linux eroge mining

## record_to_anki.sh

Records desktop audio and automatically adds it to the last card that was added. Basically a \*nix version of [this](https://rentry.co/mining#hotkey-for-audio).

By default also normalizes audio to -16LUFS, so you don't get jumpscared while doing anki reps on your laptop.

### Requirements

- Anki (duh) + [AnkiConnect addon](https://ankiweb.net/shared/info/2055492159) (2055492159)
- libnotify (notify-send)
- curl
- jq
- procps-ng (pgrep, pkill)
- ffmpeg
- mpv (can easily be replaced by audio player of your choice if you wish to do so)
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard) (Wayland users)
- [xclip](https://github.com/astrand/xclip) (X11 users)

### Usage

Run the script to start recording, run it again to stop, kill the process to abort.
Optionally pass `-c` to copy the anki media string (`[sound:xyz.mp3]`) to the clipboard instead of adding it to the latest card, and `-p` to play back the recorded audio.

Configuration is done within the shell script itself, make sure to do this before running it!

