#import "audio_devices.h"
#import <CoreAudio/CoreAudio.h>

static AudioObjectPropertyAddress createGlobalPropertyAddress(AudioObjectPropertySelector selector) {
    return (AudioObjectPropertyAddress) {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
}

NSArray* getAudioDevices() {
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDevices);

    AudioDeviceID defaultOutputDevice = getDefaultOutputDevice();

    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);
    if (status != noErr) {
        return NULL;
    }

    int deviceCount = dataSize / sizeof(AudioDeviceID);
    AudioDeviceID* deviceIDs = (AudioDeviceID*)malloc(dataSize);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, deviceIDs);

    if (status != noErr) {
        free(deviceIDs);
        return NULL;
    }

    NSMutableArray *deviceList = [NSMutableArray array];

    for (int i = 0; i < deviceCount; i++) {
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

        NSString *deviceName = getAudioDeviceName(deviceIDs[i]);

        if (deviceName) {
            NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
            [deviceInfo setObject:@(deviceIDs[i]) forKey:@"id"];
            [deviceInfo setObject:deviceName forKey:@"name"];
            [deviceInfo setObject:@(deviceIDs[i] == defaultOutputDevice) forKey:@"isDefault"];

            [deviceList addObject:deviceInfo];
        }
    }

    free(deviceIDs);
    return deviceList;
}

AudioDeviceID getDefaultOutputDevice() {
    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDefaultOutputDevice);

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propertySize, &outputDevice);

    return (result == noErr) ? outputDevice : 0;
}

NSString* getAudioDeviceName(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioObjectPropertyName);

    CFStringRef deviceName = NULL;
    UInt32 dataSize = sizeof(CFStringRef);
    OSStatus status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &deviceName);

    if (status != noErr || !deviceName) return nil;

    char deviceNameStr[128];
    if (CFStringGetCString(deviceName, deviceNameStr, sizeof(deviceNameStr), kCFStringEncodingUTF8)) {
        CFRelease(deviceName);
        return [NSString stringWithUTF8String:deviceNameStr];
    }

    CFRelease(deviceName);
    return nil;
}

bool setAudioOutputDevice(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDefaultOutputDevice);

    OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, sizeof(AudioDeviceID), &deviceID);
    return (status == noErr);
}