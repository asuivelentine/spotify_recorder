# Spotify recorder
Version 0.1.0

spotify recorder is designed to run without any special dependencies. All you need is:   
`pactl`, `dbus-send` and `ffmpeg` 

Ads won't be recorded by default.  
Every song is stored in an extra file of format `artist - title.mp3`.   
These are also set as MP3 tags.

## Usage
Start spotify and press play, then start the recorder:

`recorder.sh`  
`recorder.sh /path/to/music/store/`  
`music_folder=/path/to/music/store/ recorder.sh`  

Default music-store is `~/`  
**Don't forget the trailing `/` if you define a path!**

