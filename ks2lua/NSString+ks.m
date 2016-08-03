//
//  NSString+ks.m
//  ks2lua
//
//  Created by 小笠原やきん on 8/1/16.
//  Copyright © 2016 yaqinking. All rights reserved.
//

#import "NSString+ks.h"

@implementation NSString (ks)

- (NSString *)ks_valueForKey:(NSString *)key {
    if ([self containsString:key]) {
        NSRange range = [self rangeOfString:@"="];
        return [self substringFromIndex:range.location+1];
    }
    return nil;
}


- (NSString *)ks_transitionMethod {
    // 参考 RuntimeEngine 指令集
    if ([self isEqualToString:@"crossfade"]) {
        return @"2";
    }
    return nil;
}

- (NSString *)ks_fgPosition {
    if ([self isEqualToString:@"r"] || [self isEqualToString:@"right"]) {
        return @"3";
    }
    if ([self isEqualToString:@"l"] || [self isEqualToString:@"left"]) {
        return @"2";
    }
    if ([self isEqualToString:@"center"]) {
        return @"1";
    }
    return nil;
}

- (NSString *)ks_cgGroup {
    NSString *group = [self substringWithRange:NSMakeRange(2, 2)];
    if ([group hasPrefix:@"0"]) {
        return [group substringFromIndex:1];
    } else {
        return group;
    }
    return nil;
}

- (NSString *)ks_removeCommentNoise {
    return [[[[[self stringByReplacingOccurrencesOfString:@";" withString:@""] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"*" withString:@""] stringByReplacingOccurrencesOfString:@"[r]" withString:@""] stringByReplacingOccurrencesOfString:@"\\" withString:@""];
}

- (NSString *)ks_removeEPNameNoise {
    // dirty 233
    return [[[[[[self stringByReplacingOccurrencesOfString:@"@eval exp=\"" withString:@""]
                stringByReplacingOccurrencesOfString:@"EPingame" withString:@""] substringFromIndex:4]
              stringByReplacingOccurrencesOfString:@"\'" withString:@""]
             stringByReplacingOccurrencesOfString:@" " withString:@""]
            stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

- (NSString *)ks_removeDoubleQuates {
    return [self stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

- (NSString *)ks_removeSpeakerNoiseChracter {
    return [[self stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
}

- (NSString *)ks_removeSpeakEndChracter {
    return [self stringByReplacingOccurrencesOfString:@"[r]" withString:@""];
}

@end
