CC = clang
CFLAGS = -O3
FRAMEWORKS = -framework Cocoa -framework CoreAudio
INCLUDES = -I./include

SOURCES = src/nowplaying.mm \
          src/nowplaying_info.mm \
          src/audio_devices.mm \
          src/volume_control.mm \
          src/json_utils.mm \
          src/command_handlers.mm

nowplaying-cli: $(SOURCES)
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(INCLUDES) $(SOURCES) -o $@

clean:
	rm -f nowplaying-cli