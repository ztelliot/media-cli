#ifndef NOWPLAYING_TYPES_H
#define NOWPLAYING_TYPES_H

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import "Enums.h"

// MediaRemote function typedefs
typedef void (*MRMediaRemoteGetNowPlayingClientFunction)(dispatch_queue_t queue, void (^handler)(NSObject *info));
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *info));
typedef void (*MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction)(dispatch_queue_t queue, void (^handler)(BOOL isPlaying));
typedef void (*MRMediaRemoteSetElapsedTimeFunction)(double time);
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

// Command types
typedef enum {
    GET,
    MEDIA_COMMAND,
    SEEK,
    SKIP,
} Command;

#endif // NOWPLAYING_TYPES_H