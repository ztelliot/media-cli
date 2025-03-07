#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "types.h"
#import "audio_devices.h"
#import "volume_control.h"
#import "json_utils.h"
#import "command_handlers.h"

int main(int argc, char** argv) {
    if (argc == 1) {
        printHelp();
        return 0;
    }

    Command command = GET;
    NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];
    double seekTime = 0;
    double skipSeconds = 0;
    float volumeLevel = -1.0;

    // Static initialization of command mapping
    static NSDictionary<NSString*, NSNumber*> *cmdTranslate = nil;
    if (!cmdTranslate) {
        cmdTranslate = @{
            @"play": @(MRMediaRemoteCommandPlay),
            @"pause": @(MRMediaRemoteCommandPause),
            @"togglePlayPause": @(MRMediaRemoteCommandTogglePlayPause),
            @"next": @(MRMediaRemoteCommandNextTrack),
            @"previous": @(MRMediaRemoteCommandPreviousTrack),
        };
    }

    // Parse commands
    if (strcmp(argv[1], "get") == 0) {
        command = GET;
    }
    else if (strcmp(argv[1], "seek") == 0 && argc == 3) {
        command = SEEK;
        char *end;
        seekTime = strtod(argv[2], &end);
        if (*end != '\0') {
            fprintf(stderr, "Invalid seek time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli seek <secs>\n");
            return 1;
        }
    }
    else if (strcmp(argv[1], "skip") == 0 && argc == 3) {
        command = SKIP;
        char *end;
        skipSeconds = strtod(argv[2], &end);
        if (*end != '\0') {
            fprintf(stderr, "Invalid skip time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli skip <secs>\n");
            return 1;
        }
    }
    else if (strcmp(argv[1], "volume") == 0) {
        if (argc == 3) {
            char *end;
            volumeLevel = strtof(argv[2], &end);
            if (*end != '\0' || volumeLevel < 0.0 || volumeLevel > 1.0) {
                fprintf(stderr, "Invalid volume level: %s\n", argv[2]);
                fprintf(stderr, "Usage: nowplaying-cli volume <0.0-1.0>\n");
                return 1;
            }
            handleVolumeCommand(FALSE, volumeLevel);
        } else {
            handleVolumeCommand(TRUE, 0);
        }
        [NSApp terminate:nil];
        return 0;
    }
    else if (strcmp(argv[1], "mute") == 0) {
        handleMuteCommand();
        [NSApp terminate:nil];
        return 0;
    }
    else if (strcmp(argv[1], "devices") == 0) {
        handleDevicesCommand();
        [NSApp terminate:nil];
        return 0;
    }
    else if (strcmp(argv[1], "device") == 0 && argc == 3) {
        handleSetDeviceCommand(argv[2]);
        [NSApp terminate:nil];
        return 0;
    }
    else if (cmdTranslate[cmdStr] != nil) {
        command = MEDIA_COMMAND;
    }
    else {
        printHelp();
        return 0;
    }

    // Set up Objective-C environment
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSPanel* panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 0, 0)
        styleMask:NSWindowStyleMaskTitled
        backing:NSBackingStoreBuffered
        defer:NO];

    // Load MediaRemote framework
    CFURLRef ref = (__bridge CFURLRef)[NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

    // Handle media commands
    if (command == MEDIA_COMMAND) {
        handleMediaCommand(bundle, (MRMediaRemoteCommand)[cmdTranslate[cmdStr] intValue]);
        [NSApp terminate:nil];
        return 0;
    }
    else if (command == SEEK) {
        handleSeekCommand(bundle, seekTime);
        [NSApp terminate:nil];
        return 0;
    }

    // Handle now playing info & skip commands
    handleNowPlayingInfo(bundle, command, skipSeconds);

    [NSApp run];
    [pool release];
    return 0;
}