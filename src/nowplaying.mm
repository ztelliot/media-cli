#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Enums.h"
#import "MRContent.h"

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
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

    MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand = (MRMediaRemoteSendCommandFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
    if(command == MEDIA_COMMAND) {
        MRMediaRemoteSendCommand((MRMediaRemoteCommand) [cmdTranslate[cmdStr] intValue], nil);
        fprintf(stdout, "{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    MRMediaRemoteSetElapsedTimeFunction MRMediaRemoteSetElapsedTime = (MRMediaRemoteSetElapsedTimeFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    if(command == SEEK) {
        MRMediaRemoteSetElapsedTime(seekTime);
        fprintf(stdout, "{\"success\":true}\n");
        [NSApp terminate:nil];
        return 0;
    }

    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary* information) {
        if(command == SKIP) {
            double elapsedTime = [[information objectForKey:@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue];
            double duration = [[information objectForKey:@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue];
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
            fprintf(stdout, "{\"success\":true}\n");
            [NSApp terminate:nil];
            return;
        }

        NSMutableDictionary *modifiedInfo = [NSMutableDictionary dictionaryWithDictionary:information];
        NSError *error = nil;

        for (NSString *key in information) {
            NSObject *rawValue = [information objectForKey:key];

            if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoArtworkData"] || [key isEqualToString:@"kMRMediaRemoteNowPlayingInfoClientPropertiesData"]) {
                NSData *data = (NSData *)rawValue;
                NSString *base64 = [data base64EncodedStringWithOptions:0];
                [modifiedInfo setObject:base64 forKey:key];
            }
            else if ([key isEqualToString:@"kMRMediaRemoteNowPlayingInfoElapsedTime"]) {
                MRContentItem *item = [[objc_getClass("MRContentItem") alloc] initWithNowPlayingInfo:information];
                double position = item.metadata.calculatedPlaybackPosition;
                [modifiedInfo setObject:@(position) forKey:key];
            }
            else if ([rawValue isKindOfClass:[NSDate class]]) {
                NSTimeInterval timestamp = [(NSDate *)rawValue timeIntervalSince1970];
                [modifiedInfo setObject:@(timestamp) forKey:key];
            }
        }

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:modifiedInfo options:NSJSONWritingWithoutEscapingSlashes error:&error];
        if (!error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("{\"success\":true,\"data\":%s}\n", [jsonString UTF8String]);
            [jsonString release];
        } else {
            printf("{\"success\":false,\"msg\":\"Error converting to JSON: %s\"}\n", [[error localizedDescription] UTF8String]);
        }

        [NSApp terminate:nil];
        return;
    });

    [NSApp run];
    [pool release];
    return 0;
}
