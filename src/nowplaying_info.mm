#import "nowplaying_info.h"
#import "json_utils.h"
#import "MRContent.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

void getNowPlayingMetadata(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group) {
    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo =
        (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));

    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        for (NSString *key in info) {
            NSString *simpleKey = key;
            if ([key hasPrefix:@"kMRMediaRemoteNowPlayingInfo"]) {
                simpleKey = [key substringFromIndex:[@"kMRMediaRemoteNowPlayingInfo" length]];
                if ([simpleKey length] > 0) {
                    simpleKey = [[[simpleKey substringToIndex:1] lowercaseString]
                                stringByAppendingString:[simpleKey substringFromIndex:1]];
                }
            }

            NSObject *rawValue = [info objectForKey:key];
            if (rawValue == nil) continue;

            if ([simpleKey isEqualToString:@"artworkData"] || [simpleKey isEqualToString:@"clientPropertiesData"]) {
                NSData *data = (NSData *)rawValue;
                NSString *base64 = [data base64EncodedStringWithOptions:0];
                [fullInfo setObject:base64 forKey:simpleKey];
            }
            else if ([simpleKey isEqualToString:@"elapsedTime"]) {
                MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:info];
                double position = item.metadata.calculatedPlaybackPosition;
                [fullInfo setObject:@(position) forKey:simpleKey];
            }
            else if ([rawValue isKindOfClass:[NSDate class]]) {
                NSTimeInterval timestamp = [(NSDate *)rawValue timeIntervalSince1970];
                [fullInfo setObject:@(timestamp) forKey:simpleKey];
            }
            else {
                [fullInfo setObject:rawValue forKey:simpleKey];
            }
        }

        dispatch_group_leave(group);
    });
}

void handleNone(CFBundleRef bundle) {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo =
        (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        dispatch_group_leave(group);
    });

    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return;
}

bool handleSkipSeconds(CFBundleRef bundle, double skipSeconds) {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    bool success = false;
    bool *successPtr = &success;

    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo =
        (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));

    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        // Skip logic
        double elapsedTime = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
        double duration = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
        double skipTo = elapsedTime + skipSeconds;

        if (skipTo < 0) skipTo = 0;
        if (skipTo > duration) {
            // Cannot skip past end of track
            *successPtr = false;
        } else {
            MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime =
                (MRMediaRemoteSetElapsedTimeFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
            MRMediaRemoteSetElapsedTime(skipTo);
            *successPtr = true;
        }

        dispatch_group_leave(group);
    });

    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return success;
}

void getNowPlayingClientInfo(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group) {
    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingClientFunction MRMediaRemoteGetNowPlayingClient =
        (MRMediaRemoteGetNowPlayingClientFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingClient"));

    MRMediaRemoteGetNowPlayingClient(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSObject *info) {
        if ([info respondsToSelector:@selector(bundleIdentifier)]) {
            [fullInfo setObject:[info valueForKey:@"bundleIdentifier"] forKey:@"bundleIdentifier"];
        }

        if ([info respondsToSelector:@selector(displayName)]) {
            [fullInfo setObject:[info valueForKey:@"displayName"] forKey:@"displayName"];
        }

        dispatch_group_leave(group);
    });
}

void getNowPlayingState(CFBundleRef bundle, NSMutableDictionary *fullInfo, dispatch_group_t group) {
    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction MRMediaRemoteGetNowPlayingApplicationIsPlaying =
        (MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction)CFBundleGetFunctionPointerForName(bundle,
                                                                CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));

    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(BOOL isPlaying) {
        [fullInfo setObject:@(isPlaying) forKey:@"isPlaying"];
        dispatch_group_leave(group);
    });
}

NSDictionary* getNowPlayingInfo(CFBundleRef bundle, GetCommandType type) {
    NSMutableDictionary *fullInfo = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    // Get metadata if needed
    if (type == GET_ALL || type == GET_NOWPLAYING || type == GET_NOWPLAYING_INFO) {
        getNowPlayingMetadata(bundle, fullInfo, group);
    }

    // Get client info if needed
    if (type == GET_ALL || type == GET_NOWPLAYING || type == GET_NOWPLAYING_CLIENT) {
        getNowPlayingClientInfo(bundle, fullInfo, group);
    }

    // Get player state if needed
    if (type == GET_ALL || type == GET_NOWPLAYING || type == GET_NOWPLAYING_STATUS) {
        getNowPlayingState(bundle, fullInfo, group);
    }

    // Wait for all async operations to complete
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    long result = dispatch_group_wait(group, timeout);

    if (result == 0) {
        return [NSDictionary dictionaryWithDictionary:fullInfo];
    }

    return nil;
}
