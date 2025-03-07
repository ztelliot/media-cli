#import "json_utils.h"

void printHelp() {
    printf("Example Usage: \n");
    printf("\tnowplaying-cli get\n");
    printf("\tnowplaying-cli pause\n");
    printf("\tnowplaying-cli seek 60\n");
    printf("\tnowplaying-cli skip -10\n");
    printf("\n");
    printf("Available commands: \n");
    printf("\tget, play, pause, togglePlayPause, next, previous, seek <secs>, skip <secs>,\n");
    printf("\tvolume, volume <0.0-1.0>, mute, devices, device <id>\n");
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