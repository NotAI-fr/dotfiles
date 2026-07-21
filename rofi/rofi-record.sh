#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
FILE="$TARGET_DIR/rec_$TIMESTAMP.mp4"

# ==========================================
#  SMART TOGGLE: Stop recording if running
# ==========================================
if pgrep -x "ffmpeg" > /dev/null; then
    pkill -INT -x "ffmpeg"
    notify-send "Recorder" "󰕧 Recording saved to Videos/Recordings!"
    exit 0
fi

# ==========================================
#  STEP 1: Select Video Area
# ==========================================
VIDEO_OPTS="󰆏  Select Region\n󰹑  Capture Fullscreen"
VIDEO_CHOICE=$(echo -e "$VIDEO_OPTS" | rofi -dmenu -i -p "󰕧 Video" -theme-str '
  window { width: 300px; border-radius: 12px; padding: 10px; }
  listview { lines: 2; }
')

if [[ -z "$VIDEO_CHOICE" ]]; then exit 0; fi

# ==========================================
#  STEP 2: Select Audio Source
# ==========================================
AUDIO_OPTS="󰍭  Muted (No Audio)\n󰍬  Microphone Only\n󰎆  PC Audio Only\n󰋎  Mic + PC Audio"
AUDIO_CHOICE=$(echo -e "$AUDIO_OPTS" | rofi -dmenu -i -p "󰎆 Audio" -theme-str '
  window { width: 300px; border-radius: 12px; padding: 10px; }
  listview { lines: 4; }
')

if [[ -z "$AUDIO_CHOICE" ]]; then exit 0; fi

# ==========================================
#  GEOMETRY CALCULATION
# ==========================================
if [[ "$VIDEO_CHOICE" == *"Region"* ]]; then
    GEOM=$(slop -f "%w %h %x %y")
    if [[ -z "$GEOM" ]]; then exit 0; fi

    read -r W H X Y <<< "$GEOM"
    W=$(( W + W % 2 ))
    H=$(( H + H % 2 ))
else
    RES=$(xdpyinfo | awk '/dimensions/{print $2}')
    W=$(echo $RES | cut -d'x' -f1)
    H=$(echo $RES | cut -d'x' -f2)
    X=0
    Y=0
fi

# ==========================================
#  EXECUTION
# ==========================================
notify-send "Recorder" "󰕧 Recording starting... Press your shortcut again to stop."

# Let the Rofi menu completely fade out before recording
sleep 0.5

SYS_AUDIO=$(pactl get-default-sink).monitor

if [[ "$AUDIO_CHOICE" == *"Muted"* ]]; then
    ffmpeg -f x11grab -framerate 30 -video_size "${W}x${H}" -i :0.0+"${X},${Y}" \
           -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p \
           "$FILE" > /dev/null 2>&1 &

elif [[ "$AUDIO_CHOICE" == *"Microphone"* ]]; then
    ffmpeg -f x11grab -framerate 30 -video_size "${W}x${H}" -i :0.0+"${X},${Y}" \
           -f pulse -i default \
           -c:v libx264 -preset ultrafast -crf 22 -c:a aac -pix_fmt yuv420p \
           "$FILE" > /dev/null 2>&1 &

elif [[ "$AUDIO_CHOICE" == *"PC Audio"* ]]; then
    ffmpeg -f x11grab -framerate 30 -video_size "${W}x${H}" -i :0.0+"${X},${Y}" \
           -f pulse -i $SYS_AUDIO \
           -c:v libx264 -preset ultrafast -crf 22 -c:a aac -pix_fmt yuv420p \
           "$FILE" > /dev/null 2>&1 &

elif [[ "$AUDIO_CHOICE" == *"Mic + PC"* ]]; then
    # Captures Video (0), Mic (1), and PC Audio (2) then mixes the two audio tracks together
    ffmpeg -f x11grab -framerate 30 -video_size "${W}x${H}" -i :0.0+"${X},${Y}" \
           -f pulse -i default -f pulse -i $SYS_AUDIO \
           -filter_complex "[1:a][2:a]amix=inputs=2:duration=longest[aout]" -map 0:v -map "[aout]" \
           -c:v libx264 -preset ultrafast -crf 22 -c:a aac -pix_fmt yuv420p \
           "$FILE" > /dev/null 2>&1 &
fi
