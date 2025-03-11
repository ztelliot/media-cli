#import "command_handlers.h"
#import "nowplaying_info.h"
#import "volume_control.h"
#import "audio_devices.h"
#import "json_utils.h"
#import "types.h"
#import "MRContent.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

void handleGetCommand(CFBundleRef bundle, GetCommandType type) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSString *errorMsg = nil;

    // Get volume info if needed
    if (type == GET_ALL || type == GET_VOLUME) {
        float volume = getSystemVolume();
        if (volume >= 0) {
            [result setObject:@(volume) forKey:@"volume"];
        }
    }

    // Get device info if needed
    if (type == GET_ALL || type == GET_DEVICE) {
        AudioDeviceID device = getDefaultOutputDevice();
        if (device) {
            [result setObject:@(device) forKey:@"deviceID"];
            NSString *deviceName = getAudioDeviceName(device);
            if (deviceName) {
                [result setObject:deviceName forKey:@"deviceName"];
            }
        }
    }

    // Get nowplaying info if needed
    if (type == GET_ALL || type == GET_NOWPLAYING ||
        type == GET_NOWPLAYING_INFO || type == GET_NOWPLAYING_CLIENT ||
        type == GET_NOWPLAYING_STATUS) {
        NSDictionary *nowPlayingInfo = getNowPlayingInfo(bundle, type);

        if (nowPlayingInfo) {
            [result addEntriesFromDictionary:nowPlayingInfo];
        }
    }

    printJsonResponse(YES, @{@"data": result}, errorMsg);
}

void handleVolumeCommand(float volumeLevel) {
    bool success = setSystemVolume(volumeLevel);
    if (success) {
        printJsonResponse(YES, @{@"volume": @(volumeLevel)}, nil);
    } else {
        printJsonResponse(NO, nil, @"Failed to set volume");
    }
}

void handleMuteCommand() {
    bool success = toggleMute();
    if (success) {
        printJsonResponse(YES, nil, nil);
    } else {
        printJsonResponse(NO, nil, @"Failed to toggle mute");
    }
}

void handleDevicesCommand() {
    NSArray* devices = getAudioDevices();

    if (devices == NULL) {
        printJsonResponse(NO, nil, @"Failed to get audio devices");
        return;
    }

    printJsonResponse(YES, @{@"devices": devices}, nil);
    free(devices);
}

void handleSetDeviceCommand(const char* deviceIDStr) {
    AudioDeviceID deviceID = (AudioDeviceID)strtoul(deviceIDStr, NULL, 10);
    bool success = setAudioOutputDevice(deviceID);

    if (success) {
        printJsonResponse(YES, @{@"msg": @"Output device changed"}, nil);
    } else {
        printJsonResponse(NO, nil, @"Failed to change output device");
    }
}

void handleMediaCommand(CFBundleRef bundle, MRMediaRemoteCommand command) {
    MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand =
        (MRMediaRemoteSendCommandFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
    MRMediaRemoteSendCommand(command, nil);
    printJsonResponse(YES, nil, nil);
}

void handleSeekCommand(CFBundleRef bundle, double seekTime) {
    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime =
        (MRMediaRemoteSetElapsedTimeFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    MRMediaRemoteSetElapsedTime(seekTime);
    printJsonResponse(YES, nil, nil);
}

void handleSkipCommand(CFBundleRef bundle, double skipSeconds) {
    bool success = handleSkipSeconds(bundle, skipSeconds);
    if (success) {
        printJsonResponse(YES, nil, nil);
    } else {
        printJsonResponse(NO, nil, @"Failed to skip");
    }
}
