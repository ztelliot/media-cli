#ifndef NOWPLAYING_JSON_UTILS_H
#define NOWPLAYING_JSON_UTILS_H

#import <Foundation/Foundation.h>

// Print help information
void printHelp();

// Print JSON response with specified success status, data and error message
void printJsonResponse(bool success, NSDictionary *data, NSString *errorMsg);

#endif // NOWPLAYING_JSON_UTILS_H