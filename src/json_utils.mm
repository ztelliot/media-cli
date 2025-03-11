#import "json_utils.h"

void printHelp() {
    printf("Example Usage: \n");
    printf("\tmedia-cli get\n");
    printf("\tmedia-cli get volume\n");
    printf("\tmedia-cli get nowplaying\n");
    printf("\tmedia-cli pause\n");
    printf("\tmedia-cli seek 60\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget - all info (volume, nowplaying, default device)\n");
    printf("\tget device - default audio device\n");
    printf("\tget volume - current volume\n");
    printf("\tget nowplaying - all nowplaying info\n");
    printf("\tget nowplaying info - only nowplaying info\n");
    printf("\tget nowplaying client - only client info\n");
    printf("\tget nowplaying status - only status info\n");
    printf("\tplay, pause, togglePlayPause, next, previous, seek <secs>,\n");
    printf("\tskip <secs>, volume <0.0-1.0>, mute, devices, device <id>\n");
}

void printJsonResponse(bool success, NSDictionary *data, NSString *errorMsg) {
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithObject:@(success) forKey:@"success"];

    if (success && data) {
        [response addEntriesFromDictionary:data];
    } else if (!success && errorMsg) {
        [response setObject:errorMsg forKey:@"msg"];
    }

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response
                                                       options:NSJSONWritingWithoutEscapingSlashes
                                                         error:&error];
    if (!error) {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        printf("%s\n", [jsonString UTF8String]);
        [jsonString release];
    } else {
        printf("{\"success\":false,\"msg\":\"Error generating JSON response\"}\n");
    }
}