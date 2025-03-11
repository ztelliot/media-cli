#ifndef NOWPLAYING_AUDIO_DEVICES_H
#define NOWPLAYING_AUDIO_DEVICES_H

#import <Foundation/Foundation.h>
#import "types.h"

// Get a list of available audio devices
NSArray* getAudioDevices();

// Get the default audio output device
AudioDeviceID getDefaultOutputDevice();

// Get the name of an audio device
NSString* getAudioDeviceName(AudioDeviceID deviceID);

// Set the default audio output device
bool setAudioOutputDevice(AudioDeviceID deviceID);

#endif // NOWPLAYING_AUDIO_DEVICES_H