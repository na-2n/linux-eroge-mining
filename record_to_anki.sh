#!/bin/sh

# Config
anki_profile="ユーザー 1"
card_audio_field="SentenceAudio"
normalize=1
wait_sec=3

# Probably shouldn't need to change these
tmp_dir="/tmp"
fn="anki_audio"
rec_file="$tmp_dir/$fn.wav"
mp3_file="$tmp_dir/$fn.mp3"
norm_file="$tmp_dir/${fn}_norm.wav"
anki_media_dir="$HOME/.local/share/Anki2/$anki_profile/collection.media"
ankiconnect_url="http://localhost:8765"
replaceid=1373
appname="ankiaudio"
norm_integrated="-16"
norm_truepeak="-1.5"
norm_lra="11"

# vars
playback_audio=0
use_clipboard=0
media_name=""

ankiconnect() {
    curl $ankiconnect_url -X POST -H "Content-Type: application/json; charset=UTF-8" -d "$1" 2>/dev/null
}

_play_audio() {
    mpv --no-config --force-window=no --loop-file=no --load-scripts=no "$1"
}

_copy_mp3() {
    if ! cp $mp3_file "$anki_media_dir/$media_name"; then
        notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "Failed to copy file to Anki media directory, is it configured correctly?"
        exit 1
    fi

    if [ $1 -eq 1 ]; then
        notify-send -u low -a $appname -r $replaceid "Added to card!"
    fi

    if [ $playback_audio -eq 1 ]; then
        _play_audio "$anki_media_dir/$media_name"
    fi
}

while getopts pc o; do
    case $o in
        p):
            playback_audio=1
            ;;
        c):
            use_clipboard=1
            ;;
    esac
done

if pgrep pw-record; then
    pkill pw-record

    notify-send -u low -a $appname -r $replaceid -t 0 "Adding to card..."

    if [ $normalize -eq 1 ]; then
        if ! ffmpeg -y -i $rec_file -filter:a "silenceremove=1:0:-50dB" $norm_file; then
            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "FFmpeg error"
            exit 1
        fi

        stat=$(ffmpeg -y -i $norm_file -af "loudnorm=I=$norm_integrated:dual_mono=true:tp=$norm_truepeak:LRA=$norm_lra:print_format=json" -f null - 2>&1 | tail -n12)

        measured_integrated=$(echo $stat | jq '.input_i | tonumber')
        measured_truepeak=$(echo $stat | jq '.input_tp | tonumber')
        measured_lra=$(echo $stat | jq '.input_lra | tonumber')
        measured_thresh=$(echo $stat | jq '.input_thresh | tonumber')
        offset=$(echo $stat | jq '.target_offset | tonumber')

        if ! ffmpeg -y \
            -i $norm_file \
            -c:a libmp3lame \
            -filter_complex "loudnorm=I=$norm_integrated:
                dual_mono=true:
                tp=$norm_truepeak:
                LRA=$norm_lra:
                measured_I=$measured_integrated:
                measured_LRA=$measured_lra:
                measured_TP=$measured_truepeak:
                measured_thresh=$measured_thresh:
                offset=$offset:
                linear=true" \
            -qscale:a 4 $mp3_file
        then
            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "FFmpeg error"
            exit 1
        fi

        rm $norm_file
    else
        if ! ffmpeg -y -i $rec_file -c:a libmp3lame -filter:a "volume=0.9,silenceremove=1:0:-50dB" -qscale:a 4 $mp3_file; then
            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "FFmpeg error"
            exit 1
        fi
    fi

    rm $rec_file

    media_name="$(date +"rec_%Y%m%d_%H%M%S.mp3")"

    if [ $use_clipboard -eq 1 ]; then
        _copy_mp3 0

        mstr="[sound:$media_name]"

        case "$XDG_SESSION_TYPE" in
            "wayland")
                wl-copy $mstr
                ;;
            "x11")
                echo $mstr | xclip -i -sel clipboard
                ;;
            "")
                notify-send -u critical -a $appname -r $replaceid "Failed to copy to clipboard!" "Failed to infer whether we are running on Wayland or X11, are your XDG environment variables set up correctly?"
                exit 1
                ;;
            *)
                notify-send -u critical -a $appname -r $replaceid "Failed to copy to clipboard!" "Unknown XDG_SESSION_TYPE"
                exit 1
                ;;
        esac

        notify-send -u low -a $appname -r $replaceid "Copied to clipboard!"
    else
        if ! resp=$(ankiconnect '{"action":"findNotes","version":6,"params":{"query":"added:1"}}'); then
            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "Failed to connect to anki, is it running?"
            exit 1
        fi

        card_id=$(echo $resp | jq '.result | sort | reverse[0]')

        if ! resp=$(ankiconnect '{"action":"updateNoteFields","version":6,"params":{"note":{"id":'$card_id',"fields":{"'$card_audio_field'":"[sound:'$media_name']"}}}}'); then
            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" "Failed to connect to anki, is it running?"
            exit 1
        fi

        if echo $resp | jq -e '.error == null' >/dev/null; then
            _copy_mp3 1
        else
            err=$(echo $resp | jq '.error')

            notify-send -u critical -a $appname -r $replaceid "Adding to card failed!" $err
        fi
    fi

    rm $mp3_file
else
    if [ $wait_sec -gt 0 ]; then
        if [ $wait_sec -eq 1 ]; then
            notify-send -u low -a $appname -r $replaceid -t 0 "Recording in a second..."
        else
            notify-send -u low -a $appname -r $replaceid -t 0 "Recording in $wait_sec seconds..."
        fi

        sleep $wait_sec
    fi

    pw-record -P '{ stream.capture.sink=true }' $rec_file &

    resp=$(notify-send -u low -a $appname -r $replaceid  -t 0 -A Abort -A Stop "Recording audio...")

    case "$resp" in
        '0')
            pkill pw-record
            rm $rec_file
            ;;
        '1')
            /bin/sh $0 $@
            ;;
    esac
fi

