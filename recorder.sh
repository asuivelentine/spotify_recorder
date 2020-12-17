#! /bin/bash

if [ -z $music_folder ]; then
    music_folder="/home/${USER}/"
fi
if [ ! -z $1 ]; then
    music_folder=$1
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

    artist=$(echo $spotify_metadata | grep -o 'artist.*autoRating' | grep -o '"[a-zA-Z0-9].* ]' | tr -d '"]')
    albumartist=$(echo $spotify_metadata | grep -o 'albumArtist.*artist' | grep -o '"[a-zA-Z0-9].* ]' | tr -d '"]')
    album=$(echo $spotify_metadata | grep -o 'album.*albumArtist' | grep -o '"[a-zA-Z0-9].*)' | tr -d '")' | tr '/' '-' |xargs)
    title=$(echo $spotify_metadata | grep -o 'title.*trackNumber' | grep -o '"[a-zA-Z0-9].*)' | tr -d '")' | tr '/' '-')
    trk=$(echo $spotify_metadata | grep -o 'trackNumber.*url' | grep -o ' [0-9].*)' | tr -d ' )')
    printf -v track "%02d" $trk

    if [ -z "$artist" ]; then
        killall ffmpeg 2> /dev/null
        continue
    fi

    if [ "$artist" = "$current_record_artist" ] && [ "$title" = "$current_record_title" ] ; then
        sleep 1
        continue
    else
        killall ffmpeg 2>/dev/null
    fi

    current_record_artist=$artist
    current_record_title=$title
    filename="${music_folder}${artist}- ${title::-1}.mp3"
    
    ffmpeg -hide_banner -loglevel panic -nostats  -f pulse -ac 2 -i "$pulse_sink" \
        -metadata title="$title" -metadata artist="$artist" -metadata album="$album" -metadata album_artist="$albumartist" -metadata track="$track" "$filename" &
done
