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

    Float32 volume = 0.0;
    UInt32 propertySize = sizeof(Float32);
    AudioObjectPropertyAddress propertyAOPA = createOutputPropertyAddress(kAudioDevicePropertyVolumeScalar);

    OSStatus result = AudioObjectGetPropertyData(outputDevice, &propertyAOPA, 0, NULL, &propertySize, &volume);

    return (result == noErr) ? volume : -1.0;
}

bool setSystemVolume(float volume) {
    volume = (volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume);

    AudioDeviceID outputDevice = getDefaultOutputDevice();
    if (outputDevice == 0) return false;

    Float32 newVolume = volume;
    UInt32 propertySize = sizeof(Float32);
    AudioObjectPropertyAddress propertyAOPA = createOutputPropertyAddress(kAudioDevicePropertyVolumeScalar);

    return AudioObjectSetPropertyData(outputDevice, &propertyAOPA, 0, NULL, propertySize, &newVolume) == noErr;
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