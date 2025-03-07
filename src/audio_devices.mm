#import "audio_devices.h"
#import <CoreAudio/CoreAudio.h>

static AudioObjectPropertyAddress createGlobalPropertyAddress(AudioObjectPropertySelector selector) {
    return (AudioObjectPropertyAddress) {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
}

NSDictionary* getAudioDevices(int* count) {
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDevices);

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

    NSMutableDictionary *deviceList = [NSMutableDictionary dictionary];
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
            char deviceNameStr[128];
            if (CFStringGetCString(deviceName, deviceNameStr, sizeof(deviceNameStr), kCFStringEncodingUTF8)) {
                NSString *deviceIDString = [NSString stringWithFormat:@"%u", deviceIDs[i]];
                [deviceList setObject:[NSString stringWithUTF8String:deviceNameStr] forKey:deviceIDString];
            }
            CFRelease(deviceName);
            outputCount++;
        }
    }

    free(deviceIDs);
    *count = outputCount;
    return deviceList;
}

AudioDeviceID getDefaultOutputDevice() {
    AudioDeviceID outputDevice = 0;
    UInt32 propertySize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDefaultOutputDevice);

    OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propertySize, &outputDevice);

    return (result == noErr) ? outputDevice : 0;
}

bool setAudioOutputDevice(AudioDeviceID deviceID) {
    AudioObjectPropertyAddress propertyAddress = createGlobalPropertyAddress(kAudioHardwarePropertyDefaultOutputDevice);

    OSStatus status = AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, sizeof(AudioDeviceID), &deviceID);
    return (status == noErr);
}