#ifndef NOWPLAYING_INFO_H
#define NOWPLAYING_INFO_H

#import <CoreFoundation/CoreFoundation.h>
#import "types.h"

// Helper functions
void getNowPlayingMetadata(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);
void handleNone(CFBundleRef bundle);
bool handleSkipSeconds(CFBundleRef bundle, double skipSeconds);
void getNowPlayingClientInfo(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);
void getNowPlayingState(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);
NSDictionary* getNowPlayingInfo(CFBundleRef bundle, GetCommandType type);

#endif // NOWPLAYING_INFO_H