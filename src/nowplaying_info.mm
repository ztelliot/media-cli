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

bool processSkipCommand(CFBundleRef bundle, double skipSeconds, NSDictionary *info) {
    double elapsedTime = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
    double duration = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
    double skipTo = elapsedTime + skipSeconds;

    if (skipTo < 0) skipTo = 0;
    if (skipTo > duration) {
        printJsonResponse(NO, nil, @"Cannot skip past end of track");
        return false;
    }

    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime =
        (MRMediaRemoteSetElapsedTimeFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    MRMediaRemoteSetElapsedTime(skipTo);

    printJsonResponse(YES, nil, nil);
    return true;
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

void handleNowPlayingInfo(CFBundleRef bundle, Command command, double skipSeconds) {
    NSMutableDictionary *fullInfo = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    // Special handling for skip command
    if (command == SKIP) {
        dispatch_group_enter(group);
        MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo =
            (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));

        MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
            bool success = processSkipCommand(bundle, skipSeconds, info);
            dispatch_group_leave(group);
            if (!success) {
                [NSApp terminate:nil];
            }
        });

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
        });
        return;
    }

    // Get all information for normal nowplaying command
    getNowPlayingMetadata(bundle, fullInfo, group);
    getNowPlayingClientInfo(bundle, fullInfo, group);
    getNowPlayingState(bundle, fullInfo, group);

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        printJsonResponse(YES, @{@"data": fullInfo}, nil);
        [NSApp terminate:nil];
    });
}