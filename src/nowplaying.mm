#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingClientFunction)(dispatch_queue_t queue, void (^handler)(NSObject *info));
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *info));
typedef void (*MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction)(dispatch_queue_t queue, void (^handler)(BOOL isPlaying));
typedef void (*MRMediaRemoteSetElapsedTimeFunction)(double time);
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get\n");
    printf("\tnowplaying-cli pause\n");
    printf("\tnowplaying-cli seek 60\n");
    printf("\tnowplaying-cli skip -10\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget, play, pause, togglePlayPause, next, previous, seek <secs>, skip <secs>\n");
}

typedef enum {
    GET,
    MEDIA_COMMAND,
    SEEK,
    SKIP,
} Command;

NSDictionary<NSString*, NSNumber*> *cmdTranslate = @{
    @"play": @(MRMediaRemoteCommandPlay),
    @"pause": @(MRMediaRemoteCommandPause),
    @"togglePlayPause": @(MRMediaRemoteCommandTogglePlayPause),
    @"next": @(MRMediaRemoteCommandNextTrack),
    @"previous": @(MRMediaRemoteCommandPreviousTrack),
};

int main(int argc, char** argv) {
    if(argc == 1) {
        printHelp();
        return 0;
    }

    Command command = GET;
    NSString *cmdStr = [NSString stringWithUTF8String:argv[1]];
    double seekTime = 0;
    double skipSeconds = 0;

    if(strcmp(argv[1], "get") == 0) {
        command = GET;
    }
    else if(strcmp(argv[1], "seek") == 0 && argc == 3) {
        command = SEEK;
        char *end;
        seekTime = strtod(argv[2], &end);
        if(*end != '\0') {
            fprintf(stderr, "Invalid seek time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli seek <secs>\n");
            return 1;
        }
    }
    else if(strcmp(argv[1], "skip") == 0 && argc == 3) {
        command = SKIP;
        char *end;
        skipSeconds = strtod(argv[2], &end);
        if(*end != '\0') {
            fprintf(stderr, "Invalid skip time: %s\n", argv[2]);
            fprintf(stderr, "Usage: nowplaying-cli skip <secs>\n");
            return 1;
        }
    }
    else if(cmdTranslate[cmdStr] != nil) {
        command = MEDIA_COMMAND;
    }
    else {
        printHelp();
        return 0;
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSPanel* panel = [[NSPanel alloc] 
        initWithContentRect: NSMakeRect(0, 0, 0, 0)
        styleMask: NSWindowStyleMaskTitled
        backing: NSBackingStoreBuffered
        defer: NO];


    CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);

    if(command == MEDIA_COMMAND) {
        MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand = (MRMediaRemoteSendCommandFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
        MRMediaRemoteSendCommand((MRMediaRemoteCommand) [cmdTranslate[cmdStr] intValue], nil);
        printf("{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime = (MRMediaRemoteSetElapsedTimeFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    if(command == SEEK) {
        MRMediaRemoteSetElapsedTime(seekTime);
        printf("{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    NSMutableDictionary *fullInfo = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        if(command == SKIP) {
            double elapsedTime = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
            double duration = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
            double skipTo = elapsedTime + skipSeconds;

            if(skipTo < 0) {
                skipTo = elapsedTime - 3;
            }
            else if(skipTo >= duration) {
                skipTo = elapsedTime + 3;
            }

            if(skipTo < 0) {
                skipTo = 0;
            }
            else if(skipTo > duration) {
                return;
            }

            MRMediaRemoteSetElapsedTime(skipTo);
            dispatch_group_leave(group);
            printf("{\"success\":true}\n");
            [NSApp terminate:nil];
            return;
        }

        for (NSString *key in info) {
            NSObject *rawValue = [info objectForKey:key];

            if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] || [key isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
                NSData *data = (NSData *)rawValue;
                NSString *base64 = [data base64EncodedStringWithOptions:0];
                [fullInfo setObject:base64 forKey:key];
            }
            else if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
                MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:info];
                double position = item.metadata.calculatedPlaybackPosition;
                [fullInfo setObject:@(position) forKey:key];
            }
            else if ([rawValue isKindOfClass:[NSDate class]]) {
                NSTimeInterval timestamp = [(NSDate *)rawValue timeIntervalSince1970];
                [fullInfo setObject:@(timestamp) forKey:key];
            }
            else {
                [fullInfo setObject:rawValue forKey:key];
            }
        }

        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingClientFunction MRMediaRemoteGetNowPlayingClient = (MRMediaRemoteGetNowPlayingClientFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingClient"));
    MRMediaRemoteGetNowPlayingClient(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSObject *info) {
        NSString *bundleIdentifier = nil;
        if ([info respondsToSelector:@selector(bundleIdentifier)]) {
            bundleIdentifier = [info valueForKey:@"bundleIdentifier"];
            [fullInfo setObject:bundleIdentifier forKey:@"kMRMediaRemoteGetNowPlayingClientBundleIdentifier"];
        }

        NSString *displayName = nil;
        if ([info respondsToSelector:@selector(displayName)]) {
            displayName = [info valueForKey:@"displayName"];
            [fullInfo setObject:displayName forKey:@"kMRMediaRemoteGetNowPlayingClientDisplayName"];
        }

        dispatch_group_leave(group);
    });

    dispatch_group_enter(group);
    MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction MRMediaRemoteGetNowPlayingApplicationIsPlaying = (MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(BOOL isPlaying) {
        [fullInfo setObject:@(isPlaying) forKey:@"kMRMediaRemoteGetNowPlayingApplicationIsPlaying"];
        dispatch_group_leave(group);
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fullInfo options:NSJSONWritingWithoutEscapingSlashes error:&error];
        if (!error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("{\"success\":true,\"data\":%s}\n", [jsonString UTF8String]);
            [jsonString release];
        } else {
            printf("{\"success\":false,\"msg\":\"Error converting to JSON: %s\"}\n", [[error localizedDescription] UTF8String]);
        }

        [NSApp terminate:nil];
    });

    [NSApp run];
    [pool release];
    return 0;
}
