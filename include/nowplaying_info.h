#ifndef NOWPLAYING_INFO_H
#define NOWPLAYING_INFO_H

#import <CoreFoundation/CoreFoundation.h>
#import "types.h"

// Function to process and return now playing info
void handleNowPlayingInfo(CFBundleRef bundle, Command command, double skipSeconds);

// Helper functions
void getNowPlayingMetadata(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);
bool processSkipCommand(CFBundleRef bundle, double skipSeconds, NSDictionary *info);
void getNowPlayingClientInfo(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);
void getNowPlayingState(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group);

#endif // NOWPLAYING_INFO_H