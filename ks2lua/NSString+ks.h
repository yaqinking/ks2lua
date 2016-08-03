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
/**
 *  转换背景切换模式
 *  0:直接切换，1:遮罩切换，2:淡入，3:淡出
 *  @return RetimeEngine 对应切换背景模式
 */
- (NSString *)ks_transitionMethod;
- (NSString *)ks_fgPosition;
- (NSString *)ks_removeCommentNoise;
- (NSString *)ks_removeEPNameNoise;
- (NSString *)ks_removeDoubleQuates;
- (NSString *)ks_removeSpeakerNoiseChracter;
- (NSString *)ks_removeSpeakEndChracter;
- (NSString *)ks_cgGroup;

@end
