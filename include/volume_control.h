#ifndef NOWPLAYING_VOLUME_CONTROL_H
#define NOWPLAYING_VOLUME_CONTROL_H

// Get system volume (0.0 to 1.0)
float getSystemVolume();

// Set system volume (0.0 to 1.0)
bool setSystemVolume(float volume);

// Toggle mute state
bool toggleMute();

#endif // NOWPLAYING_VOLUME_CONTROL_H