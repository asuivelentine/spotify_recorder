#! /bin/bash

args=("$@")

if [ -z $music_folder ]; then
    music_folder="/home/${USER}/"
fi
if [ ! -z $1 ]; then
    if [ ${1:0:1} = '-' ]; then
        if [ ${1:1:1} = 'h' ]; then
            echo -e 'Usage Help:\n  The first non-option arg is a music folder.'
            echo -e '  If no music folder is supplied then the default is "/home/$USER/" and filename is "$artist- $title.mp3"'
            echo -e '  The -f option parses next arg as filepath template. These are supported tokens:'
            echo -e '\n\t$album - Album Title\n\t$albumartist - Album Artist\n\t$artist - Artist/Band Name\n\t$title - Track Title\n\t$track - Track Number\n'
            echo -e '  Be sure to use single quotes when passing the filepath arg to prevent shell expansion.'
            echo -e "    eg. $0 -f '"'~/Downloads/$artist/$album/$track - $title.mp3'"'"
            echo -e '  As shortcut, -a sets filepath to "$music_folder/$album/$track - $title.mp3"\n  Directories are created as needed.'
            echo -e '  If the eyed3 pkg is installed then album art will be written to image tags.'
            exit 0
        elif [[ ${1:1:1} = 'a' && ! -z $2 ]]; then
            music_folder="$2"
            expand_filename() {
                filename="$music_folder/$album/$track - $title.mp3"
            }
        elif [[ ${1:1:1} = 'f' && ! -z $2 ]]; then
            expand_filename() {
                filename=`eval echo "${args[1]}"`
            }
        else
            echo "Unsupported option ${1:1:1}"
            exit 1
        fi
    else
        music_folder="$1"
        expand_filename() {
            filename="$music_folder$artist- $title.mp3"
        }
    fi
fi

if [ -z "$(pidof spotify)" ]; then
    echo "spotify not running... exit..."
    exit 1
fi

pulse_sink=$(
    pactl list sink-inputs \
        | fgrep --regexp='Sink' --regexp='media.name = "Spotify"' \
        | head -n2 | tail -n1 \
        | grep -o '[0-9]*'
)

current_record_artist=""
current_record_title=""

while true; do
    spotify_metadata=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
        /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
        string:org.mpris.MediaPlayer2.Player string:Metadata 2>/dev/null)
    readarray -t data <<<$(echo $spotify_metadata | grep -Po '".*?" (\)|v|])| [0-9]+' | tr '/' '-')
    arturl=${data[5]:1:-3}
    arturl="https://i.scdn.co/image/"${arturl##*-}  # fixup for buggy art url metadata
    album=${data[7]:1:-3}
    albumartist=${data[9]:1:-3}
    artist=${data[11]:1:-3}
    title=${data[17]:1:-3}
    printf -v track "%02d" ${data[19]}

    if [ -z "$artist" ]; then
        killall ffmpeg 2> /dev/null
        continue
    fi

    if [ "$artist" = "$current_record_artist" ] && [ "$title" = "$current_record_title" ] ; then
        sleep 1
        continue
    else
        killall ffmpeg 2>/dev/null
        if command -v eyeD3 &> /dev/null; then
            if [[ -f "$recdir/folder.jpg" && -f "$filename" ]]; then
                eyeD3 -Q --add-image "$recdir/folder.jpg:FRONT_COVER" "$filename" &>/dev/null
            fi
        fi
    fi

    current_record_artist=$artist
    current_record_title=$title
    expand_filename
    recdir="$(dirname "$filename")"
    mkdir -p "$recdir"

    echo "Recording to $filename"
    ffmpeg -hide_banner -loglevel panic -nostats  -f pulse -ac 2 -i "$pulse_sink" \
        -metadata title="$title" -metadata artist="$artist" -metadata album="$album" -metadata album_artist="$albumartist" -metadata track="$track" "$filename" &

    if [ ! -f "$recdir/folder.jpg" ]; then
        wget "$arturl" -q -O "$recdir/folder.jpg"
    fi
done
