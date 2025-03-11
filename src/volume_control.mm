#import "audio_devices.h"
#import "volume_control.h"
#import <CoreAudio/CoreAudio.h>

static AudioObjectPropertyAddress createOutputPropertyAddress(AudioObjectPropertySelector selector) {
    return (AudioObjectPropertyAddress) {
        selector,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMain
    };
}

float getSystemVolume() {
    AudioDeviceID outputDevice = getDefaultOutputDevice();
    if (outputDevice == 0) return -1.0;

    // First check if the device has the volume property on main element
    AudioObjectPropertyAddress propertyAOPA = createOutputPropertyAddress(kAudioDevicePropertyVolumeScalar);
    Boolean hasVolumeProperty = AudioObjectHasProperty(outputDevice, &propertyAOPA);

    // If device has main volume property, use it
    if (hasVolumeProperty) {
        Float32 volume = 0.0;
        UInt32 propertySize = sizeof(Float32);
        OSStatus result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA, 0, NULL, &propertySize, &volume);
        return (result == noErr) ? volume : -1.0;
    }

    // Otherwise, get the actual channels from the stream configuration
    AudioObjectPropertyAddress channelCountAOPA = createOutputPropertyAddress(kAudioDevicePropertyStreamConfiguration);
    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(outputDevice, &channelCountAOPA, 0, NULL, &dataSize);
    if (status != noErr || dataSize == 0) {
        return -1.0;
    }

    // Get the AudioBufferList
    AudioBufferList* bufferList = (AudioBufferList*)malloc(dataSize);
    if (!bufferList) return -1.0;

    status = AudioObjectGetPropertyData(outputDevice, &channelCountAOPA, 0, NULL, &dataSize, bufferList);
    if (status != noErr || bufferList == NULL || bufferList->mNumberBuffers == 0) {
        free(bufferList);
        return -1.0;
    }

    Float32 volume = 0.0;
    bool success = false;
    for (UInt32 channel = 1; channel <= bufferList->mBuffers[0].mNumberChannels; channel++) {
        propertyAOPA.mElement = channel;
        if (AudioObjectHasProperty(outputDevice, &propertyAOPA)) {
            Float32 channelVolume = 0.0;
            UInt32 propertySize = sizeof(Float32);
            OSStatus result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA, 0, NULL, &propertySize, &channelVolume);
            if (result == noErr) {
                volume += channelVolume;
                success = true;
            }
        }
    }
    volume /= bufferList->mBuffers[0].mNumberChannels;

    free(bufferList);
    return success ? volume : -1.0;
}

bool setSystemVolume(float volume) {
    volume = (volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume);

    AudioDeviceID outputDevice = getDefaultOutputDevice();
    if (outputDevice == 0) return false;

    // First check if the device has the volume property on main element
    AudioObjectPropertyAddress propertyAOPA = createOutputPropertyAddress(kAudioDevicePropertyVolumeScalar);
    Boolean hasVolumeProperty = AudioObjectHasProperty(outputDevice, &propertyAOPA);

    if (hasVolumeProperty) {
        return AudioObjectSetPropertyData(outputDevice, &propertyAOPA, 0, NULL, sizeof(Float32), &volume) == noErr;
    }

    // Otherwise, set the volume on all channels
    AudioObjectPropertyAddress channelCountAOPA = createOutputPropertyAddress(kAudioDevicePropertyStreamConfiguration);
    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(outputDevice, &channelCountAOPA, 0, NULL, &dataSize);
    if (status != noErr || dataSize == 0) {
        return false;
    }

    // Get the AudioBufferList
    AudioBufferList* bufferList = (AudioBufferList*)malloc(dataSize);
    if (!bufferList) return false;

    status = AudioObjectGetPropertyData(outputDevice, &channelCountAOPA, 0, NULL, &dataSize, bufferList);
    if (status != noErr || bufferList == NULL || bufferList->mNumberBuffers == 0) {
        free(bufferList);
        return false;
    }

    bool success = false;
    for (UInt32 channel = 1; channel <= bufferList->mBuffers[0].mNumberChannels; channel++) {
        propertyAOPA.mElement = channel;
        if (AudioObjectHasProperty(outputDevice, &propertyAOPA)) {
            success = AudioObjectSetPropertyData(outputDevice, &propertyAOPA, 0, NULL, sizeof(Float32), &volume) == noErr;
        }
    }

    free(bufferList);
    return success;
}

bool toggleMute() {
    AudioDeviceID outputDevice = getDefaultOutputDevice();
    if (outputDevice == 0) return false;

    UInt32 mute = 0;
    UInt32 propertySize = sizeof(UInt32);
    AudioObjectPropertyAddress propertyAOPA = createOutputPropertyAddress(kAudioDevicePropertyMute);

    OSStatus result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA, 0, NULL, &propertySize, &mute);

    if (result != noErr) return false;

    mute = mute ? 0 : 1;

    return AudioObjectSetPropertyData(outputDevice, &propertyAOPA, 0, NULL, propertySize, &mute) == noErr;
}