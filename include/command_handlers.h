#ifndef NOWPLAYING_COMMAND_HANDLERS_H
#define NOWPLAYING_COMMAND_HANDLERS_H

#import <Foundation/Foundation.h>
#import "types.h"

// Handle volume commands
void handleVolumeCommand(bool getOnly, float volumeLevel);

// Handle mute/unmute command
void handleMuteCommand();

// Handle listing audio devices
void handleDevicesCommand();

// Handle setting the active audio device
void handleSetDeviceCommand(const char* deviceIDStr);

// Handle media playback commands
void handleMediaCommand(CFBundleRef bundle, MRMediaRemoteCommand command);

// Handle seek command
void handleSeekCommand(CFBundleRef bundle, double seekTime);

// Handle retrieving now playing information
void handleNowPlayingInfo(CFBundleRef bundle, Command command, double skipSeconds);

#endif // NOWPLAYING_COMMAND_HANDLERS_H