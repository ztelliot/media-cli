CC = clang
CFLAGS = -O3
ARCH = -arch x86_64 -arch arm64
FRAMEWORKS = -framework Cocoa -framework CoreAudio
INCLUDES = -I./include

SOURCES = src/media_cli.mm \
          src/nowplaying_info.mm \
          src/audio_devices.mm \
          src/volume_control.mm \
          src/json_utils.mm \
          src/command_handlers.mm

media-cli: $(SOURCES)
	$(CC) $(CFLAGS) $(ARCH) $(FRAMEWORKS) $(INCLUDES) $(SOURCES) -o $@

clean:
	rm -f media-cli