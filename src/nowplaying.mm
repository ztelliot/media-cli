#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreAudio/CoreAudio.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingClientFunction)(dispatch_queue_t queue, void (^handler)(NSObject *info));
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *info));
typedef void (*MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction)(dispatch_queue_t queue, void (^handler)(BOOL isPlaying));
typedef void (*MRMediaRemoteSetElapsedTimeFunction)(double time);
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

typedef struct {
    AudioDeviceID deviceID;
    char name[128];
    bool isOutput;
} AudioDeviceInfo;

AudioDeviceInfo* getAudioDevices(int* count) {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);
    if (status != noErr) {
        *count = 0;
        return NULL;
    }

    int deviceCount = dataSize / sizeof(AudioDeviceID);
    AudioDeviceID* deviceIDs = (AudioDeviceID*)malloc(dataSize);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, deviceIDs);

    if (status != noErr) {
        free(deviceIDs);
        *count = 0;
        return NULL;
    }

    AudioDeviceInfo* devices = (AudioDeviceInfo*)malloc(sizeof(AudioDeviceInfo) * deviceCount);
    int outputCount = 0;

    for (int i = 0; i < deviceCount; i++) {
        // Check if device has output streams
        propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput;

        dataSize = 0;
        status = AudioObjectGetPropertyDataSize(deviceIDs[i], &propertyAddress, 0, NULL, &dataSize);
        if (status != noErr || dataSize == 0) continue;

        AudioBufferList* bufferList = (AudioBufferList*)malloc(dataSize);
        status = AudioObjectGetPropertyData(deviceIDs[i], &propertyAddress, 0, NULL, &dataSize, bufferList);

        bool hasOutputChannels = false;
        if (status == noErr) {
            for (UInt32 j = 0; j < bufferList->mNumberBuffers; j++) {
                if (bufferList->mBuffers[j].mNumberChannels > 0) {
                    hasOutputChannels = true;
                    break;
                }
            }
        }
        free(bufferList);

        if (!hasOutputChannels) continue;

        // Get device name
        propertyAddress.mSelector = kAudioObjectPropertyName;
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;

        CFStringRef deviceName = NULL;
        dataSize = sizeof(CFStringRef);
        status = AudioObjectGetPropertyData(deviceIDs[i], &propertyAddress, 0, NULL, &dataSize, &deviceName);

        if (status == noErr && deviceName) {
            devices[outputCount].deviceID = deviceIDs[i];
            devices[outputCount].isOutput = true;
            CFStringGetCString(deviceName, devices[outputCount].name, 128, kCFStringEncodingUTF8);
            CFRelease(deviceName);
            outputCount++;
        }
    }

    free(deviceIDs);
    *count = outputCount;
    return devices;
}

bool setAudioOutputDevice(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress,
                                             0, NULL, sizeof(AudioDeviceID), &deviceID);
    return (status == noErr);
}

void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get\n");
    printf("\tnowplaying-cli pause\n");
    printf("\tnowplaying-cli seek 60\n");
    printf("\tnowplaying-cli skip -10\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget, play, pause, togglePlayPause, next, previous, seek <secs>, skip <secs>,\n");
    printf("\tvolume, volume <0.0-1.0>, mute, devices, device <id>\n");
}

typedef enum {
    GET,
    MEDIA_COMMAND,
    SEEK,
    SKIP,
    GET_VOLUME,
    SET_VOLUME,
    TOGGLE_MUTE,
    LIST_DEVICES,
    SET_DEVICE,
} Command;

NSDictionary<NSString*, NSNumber*> *cmdTranslate = @{
    @"play": @(MRMediaRemoteCommandPlay),
    @"pause": @(MRMediaRemoteCommandPause),
    @"togglePlayPause": @(MRMediaRemoteCommandTogglePlayPause),
    @"next": @(MRMediaRemoteCommandNextTrack),
    @"previous": @(MRMediaRemoteCommandPreviousTrack),
};

float getSystemVolume() {
    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAOPA = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAOPA,
                                               0, NULL, &propertySize, &outputDevice);
    if (result != noErr) return -1.0;

    Float32 volume = 0.0;
    propertySize = sizeof(Float32);
    propertyAOPA.mSelector = kAudioDevicePropertyVolumeScalar;
    propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;

    result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA,
                                     0, NULL, &propertySize, &volume);
    if (result != noErr) return -1.0;

    return volume;
}

bool setSystemVolume(float volume) {
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAOPA = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAOPA,
                                               0, NULL, &propertySize, &outputDevice);
    if (result != noErr) return false;

    Float32 newVolume = volume;
    propertySize = sizeof(Float32);
    propertyAOPA.mSelector = kAudioDevicePropertyVolumeScalar;
    propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;

    result = AudioObjectSetPropertyData(outputDevice, &propertyAOPA,
                                     0, NULL, propertySize, &newVolume);
    return result == noErr;
}

bool getMuteState() {
    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAOPA = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAOPA,
                                               0, NULL, &propertySize, &outputDevice);
    if (result != noErr) return false;

    UInt32 mute = 0;
    propertySize = sizeof(UInt32);
    propertyAOPA.mSelector = kAudioDevicePropertyMute;
    propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;

    result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA,
                                     0, NULL, &propertySize, &mute);
    if (result != noErr) return false;

    return mute == 1;
}

bool toggleMute() {
    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAOPA = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAOPA,
                                               0, NULL, &propertySize, &outputDevice);
    if (result != noErr) return false;

    UInt32 mute = 0;
    propertySize = sizeof(UInt32);
    propertyAOPA.mSelector = kAudioDevicePropertyMute;
    propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;

    result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA,
                                     0, NULL, &propertySize, &mute);
    if (result != noErr) return false;

    mute = mute ? 0 : 1;

    result = AudioObjectSetPropertyData(outputDevice, &propertyAOPA,
                                     0, NULL, propertySize, &mute);
    return result == noErr;
}

int main(int argc, char** argv) {
    if(argc == 1) {
        printHelp();
        return 0;
    }

    Command command = GET;
    NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];
    double seekTime = 0;
    double skipSeconds = 0;
    float volumeLevel = -1.0;

    if(strcmp(argv[1], "get") == 0) {
        command = GET;
    }
    else if(strcmp(argv[1], "seek") == 0 && argc == 3) {
        command = SEEK;
        char *end;
        seekTime = strtod(argv[2], &end);
        if(*end != '\0') {
            fprintf(stderr, "Invalid seek time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli seek <secs>\n");
            return 1;
        }
    }
    else if(strcmp(argv[1], "skip") == 0 && argc == 3) {
        command = SKIP;
        char *end;
        skipSeconds = strtod(argv[2], &end);
        if(*end != '\0') {
            fprintf(stderr, "Invalid skip time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli skip <secs>\n");
            return 1;
        }
    }
    else if(strcmp(argv[1], "volume") == 0) {
        if(argc == 3) {
            command = SET_VOLUME;
            char *end;
            volumeLevel = strtof(argv[2], &end);
            if(*end != '\0' || volumeLevel < 0.0 || volumeLevel > 1.0) {
                fprintf(stderr, "Invalid volume level: %s\n", argv[2]);
                fprintf(stderr, "Usage: nowplaying-cli volume <0.0-1.0>\n");
                return 1;
            }
        } else {
            command = GET_VOLUME;
        }
    }
    else if(strcmp(argv[1], "mute") == 0) {
        command = TOGGLE_MUTE;
    }
    else if(strcmp(argv[1], "devices") == 0) {
        command = LIST_DEVICES;
    }
    else if(strcmp(argv[1], "device") == 0 && argc == 3) {
        command = SET_DEVICE;
        // Device ID is handled later
    }
    else if(cmdTranslate[cmdStr] != nil) {
        command = MEDIA_COMMAND;
    }
    else {
        printHelp();
        return 0;
    }

    if(command == GET_VOLUME) {
        float volume = getSystemVolume();
        if(volume >= 0) {
            printf("{\"success\":true,\"volume\":%.2f}\n", volume);
        } else {
            printf("{\"success\":false,\"msg\":\"Failed to get volume\"}\n");
        }
        [NSApp terminate:nil];
        return 0;
    }
    else if(command == SET_VOLUME) {
        bool success = setSystemVolume(volumeLevel);
        if(success) {
            printf("{\"success\":true,\"volume\":%.2f}\n", volumeLevel);
        } else {
            printf("{\"success\":false,\"msg\":\"Failed to set volume\"}\n");
        }
        [NSApp terminate:nil];
        return 0;
    }
    else if(command == TOGGLE_MUTE) {
        bool wasMuted = getMuteState();
        bool success = toggleMute();
        if(success) {
            printf("{\"success\":true,\"muted\":%s}\n", wasMuted ? "false" : "true");
        } else {
            printf("{\"success\":false,\"msg\":\"Failed to toggle mute\"}\n");
        }
        [NSApp terminate:nil];
        return 0;
    }
    else if(command == LIST_DEVICES) {
        int deviceCount = 0;
        AudioDeviceInfo* devices = getAudioDevices(&deviceCount);

        if (devices == NULL) {
            printf("{\"success\":false,\"msg\":\"Failed to get audio devices\"}\n");
            [NSApp terminate:nil];
            return 1;
        }

        NSMutableDictionary *deviceList = [NSMutableDictionary dictionary];
        for (int i = 0; i < deviceCount; i++) {
            NSString *deviceName = [NSString stringWithUTF8String:devices[i].name];
            [deviceList setObject:@(devices[i].deviceID) forKey:deviceName];
        }

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:deviceList options:NSJSONWritingWithoutEscapingSlashes error:&error];
        if (!error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("{\"success\":true,\"devices\":%s}\n", [jsonString UTF8String]);
            [jsonString release];
        } else {
            printf("{\"success\":false,\"msg\":\"Error converting to JSON: %s\"}\n", [[error localizedDescription] UTF8String]);
        }

        free(devices);
        [NSApp terminate:nil];
        return 0;
    }
    else if(command == SET_DEVICE) {
        AudioDeviceID deviceID = (AudioDeviceID)strtoul(argv[2], NULL, 10);
        bool success = setAudioOutputDevice(deviceID);

        if (success) {
            printf("{\"success\":true,\"msg\":\"Output device changed\"}\n");
        } else {
            printf("{\"success\":false,\"msg\":\"Failed to change output device\"}\n");
        }

        [NSApp terminate:nil];
        return 0;
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSPanel* panel = [[NSPanel alloc] 
        initWithContentRect: NSMakeRect(0, 0, 0, 0)
        styleMask: NSWindowStyleMaskTitled
        backing: NSBackingStoreBuffered
        defer: NO];


    CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

    if(command == MEDIA_COMMAND) {
        MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand = (MRMediaRemoteSendCommandFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
        MRMediaRemoteSendCommand((MRMediaRemoteCommand) [cmdTranslate[cmdStr] intValue], nil);
        printf("{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime = (MRMediaRemoteSetElapsedTimeFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    if(command == SEEK) {
        MRMediaRemoteSetElapsedTime(seekTime);
        printf("{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    NSMutableDictionary *fullInfo = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        if(command == SKIP) {
            double elapsedTime = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
            double duration = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
            double skipTo = elapsedTime + skipSeconds;

            if(skipTo < 0) {
                skipTo = elapsedTime - 3;
            }
            else if(skipTo >= duration) {
                skipTo = elapsedTime + 3;
            }

            if(skipTo < 0) {
                skipTo = 0;
            }
            else if(skipTo > duration) {
                return;
            }

            MRMediaRemoteSetElapsedTime(skipTo);
            dispatch_group_leave(group);
            printf("{\"success\":true}\n");
            [NSApp terminate:nil];
            return;
        }

        for (NSString *key in info) {
            NSString *simpleKey = key;
            if ([key hasPrefix:@"kMRMediaRemoteNowPlayingInfo"]) {
                simpleKey = [key substringFromIndex:[@"kMRMediaRemoteNowPlayingInfo" length]];
                if ([simpleKey length] > 0) {
                    simpleKey = [[[simpleKey substringToIndex:1] lowercaseString] stringByAppendingString:[simpleKey substringFromIndex:1]];
                }
            }

            NSObject *rawValue = [info objectForKey:key];
            if (rawValue == nil) {
                continue;
            }

            if ([simpleKey isEqualToString:@"artworkData"] || [simpleKey isEqualToString:@"clientPropertiesData"]) {
                NSData *data = (NSData *)rawValue;
                NSString *base64 = [data base64EncodedStringWithOptions:0];
                [fullInfo setObject:base64 forKey:simpleKey];
            }
            else if ([simpleKey isEqualToString:@"elapsedTime"]) {
                MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:info];
                double position = item.metadata.calculatedPlaybackPosition;
                [fullInfo setObject:@(position) forKey:simpleKey];
            }
            else if ([rawValue isKindOfClass:[NSDate class]]) {
                NSTimeInterval timestamp = [(NSDate *)rawValue timeIntervalSince1970];
                [fullInfo setObject:@(timestamp) forKey:simpleKey];
            }
            else {
                [fullInfo setObject:rawValue forKey:simpleKey];
            }
        }

        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingClientFunction MRMediaRemoteGetNowPlayingClient = (MRMediaRemoteGetNowPlayingClientFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingClient"));
    MRMediaRemoteGetNowPlayingClient(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSObject *info) {
        if ([info respondsToSelector:@selector(bundleIdentifier)]) {
            NSString *bundleIdentifier = [info valueForKey:@"bundleIdentifier"];
            [fullInfo setObject:bundleIdentifier forKey:@"bundleIdentifier"];
        }

        if ([info respondsToSelector:@selector(displayName)]) {
            NSString *displayName = [info valueForKey:@"displayName"];
            [fullInfo setObject:displayName forKey:@"displayName"];
        }

        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction MRMediaRemoteGetNowPlayingApplicationIsPlaying = (MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(BOOL isPlaying) {
        [fullInfo setObject:@(isPlaying) forKey:@"isPlaying"];
        dispatch_group_leave(group);
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fullInfo options:NSJSONWritingWithoutEscapingSlashes error:&error];
        if (!error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("{\"success\":true,\"data\":%s}\n", [jsonString UTF8String]);
            [jsonString release];
        } else {
            printf("{\"success\":false,\"msg\":\"Error converting to JSON: %s\"}\n", [[error localizedDescription] UTF8String]);
        }

        [NSApp terminate:nil];
    });

    [NSApp run];
    [pool release];
    return 0;
}
