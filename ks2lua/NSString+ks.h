//
//  NSString+ks.h
//  ks2lua
//
//  Created by 小笠原やきん on 8/1/16.
//  Copyright © 2016 yaqinking. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (ks)

/**
 *  从字符串中得到一个 ks Key 的 Value
 *
 *  @param key ks Key
 *  @param obj Value
 *
 *  @return 处理后的 Value
 */
- (NSString *)ks_valueForKey:(NSString *)key;
- (NSString *)ks_transitionMethod;
- (NSString *)ks_removeCommentNoise;
- (NSString *)ks_removeEPNameNoise;
- (NSString *)ks_removeDoubleQuates;
- (NSString *)ks_removeSpeakerNoiseChracter;
- (NSString *)ks_removeSpeakEndChracter;

@end
