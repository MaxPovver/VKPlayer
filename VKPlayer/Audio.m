//
//  Audio.m
//  VKPlayer
//
//  Created by Максим Чистов on 14.03.15.
//  Copyright (c) 2015 Максим Чистов. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VKSdk/VKSdk.h>

#import "Audio.h"

@interface Audio ()

@end

@implementation Audio
NSString *url,*artist,*title;
int duration;

- (instancetype)init:(VKAudio*) withAudio
{
    url =  [NSString stringWithString: [withAudio url] ];
    artist = [NSString stringWithString: [withAudio artist]];
    title = [NSString stringWithString: [withAudio title]];
    duration = [[withAudio duration] integerValue];
    return self;
}
-(NSDictionary*)toJSON {
    return @{@"url":url,@"title":artist,@"artist":title,@"duration":[NSNumber numberWithInt:duration]};
}
- (instancetype)initjs:(NSDictionary*) withJSON
{
    url =  @"";
    artist = @"";
    title = @"";
    duration = 0;
    return self;
}

@end