#import "command_handlers.h"
#import "nowplaying_info.h"
#import "volume_control.h"
#import "audio_devices.h"
#import "json_utils.h"
#import "types.h"
#import "MRContent.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

void handleVolumeCommand(bool getOnly, float volumeLevel) {
    if (getOnly) {
        float volume = getSystemVolume();
        if (volume >= 0) {
            printJsonResponse(YES, @{@"volume": @(volume)}, nil);
        } else {
            printJsonResponse(NO, nil, @"Failed to get volume");
        }
    } else {
        bool success = setSystemVolume(volumeLevel);
        if (success) {
            printJsonResponse(YES, @{@"volume": @(volumeLevel)}, nil);
        } else {
            printJsonResponse(NO, nil, @"Failed to set volume");
        }
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
    int deviceCount = 0;
    NSDictionary* devices = getAudioDevices(&deviceCount);

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
