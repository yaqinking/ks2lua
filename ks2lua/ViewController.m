//
//  ViewController.m
//  ks2lua
//
//  Created by 小笠原やきん on 7/29/16.
//  Copyright © 2016 yaqinking. All rights reserved.
//

#import "ViewController.h"

static NSString * const ksFileNameKey = @"storage";

@interface ViewController()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *sourcePathLabel;

typedef void (^ksEachBlock)(NSString *obj);

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

# pragma mark Interface Builder Action

- (IBAction)choosePath:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles       = NO;
    openPanel.canChooseDirectories = YES;
    openPanel.prompt               = @"OK";
    if ([openPanel runModal] == NSModalResponseOK) {
        NSURL *url = [openPanel URL];
        self.sourcePathLabel.stringValue = url.path;
    }
}

- (IBAction)startAnalysis:(id)sender {
    NSString *path = self.sourcePathLabel.stringValue;
    NSURL *pathURL = [NSURL URLWithString:path];
    if (path.length < 1 || [pathURL.pathExtension isEqualToString:@"ks"]) {
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:pathURL
                                               includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             if (error) {
                                                 NSLog(@"[Error] %@ (%@)", error, url);
                                                 return NO;
                                             }
                                             
                                             return YES;
                                         }];
    
    NSMutableArray *mutableFileURLs = [NSMutableArray array];
    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        // Skip directories with '_' prefix, for example
        if ([filename hasPrefix:@"_"] && [isDirectory boolValue]) {
            [enumerator skipDescendants];
            continue;
        }
        
        if (![isDirectory boolValue]) {
            [mutableFileURLs addObject:fileURL];
        }
    }
    
    unsigned long encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    [mutableFileURLs enumerateObjectsUsingBlock:^(id  _Nonnull filePath, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *url = filePath;
        NSError *error = nil;
        NSString *contentString = [NSString stringWithContentsOfFile:url.path encoding:encode error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
        NSString *path = [url.path stringByReplacingOccurrencesOfString:@".ks" withString:@".lua"];
        [self tranlateKs:contentString saveTo:path];
    }];
    
}

- (void)tranlateKs:(NSString *)content saveTo:(NSString *)path {
    NSArray<NSString *> *linesArray = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    __block NSString *chracterName;
    __block NSString *soundEffectName;
    __block NSString *fgName;
    __block NSString *voName;
    
    __block NSMutableString *outputText = [NSMutableString new];
    [linesArray enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        // 处理注释
        if ([line containsString:@";"]) {
            [outputText appendFormat:@"-- %@\r",[self removeCommentNoise:line]];
            return;
        }
        if ([line containsString:@"@playse"]) {
            NSArray<NSString *> *array = [line componentsSeparatedByString:@" "];
            __block NSString *loop;
            __block NSString *buf;
            [array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj containsString:@"="]) {
                    obj = [self removeDoubleQuates:obj];
                    NSRange range = [obj rangeOfString:@"="];
                    NSString *name = [obj substringFromIndex:range.location+1];
                    if ([obj containsString:@"storage"]) {
                        soundEffectName = name;
                    } else if ([obj containsString:@"loop"]) {
                        loop = name;
                    } else if ([obj containsString:@"buf"]) {
                        NSString *tempBuf = [self valueForksKey:@"buf" From:obj];
                        if (tempBuf) {
                            buf = tempBuf;
                        }
                    }
                }
            }];
            // 不带 loop 的 se
            if (buf.length > 0) {
                line = [NSString stringWithFormat:@"se(\"%@\")\r", soundEffectName];
                [outputText appendString: line];
                return;
            }
            if ([loop isEqualToString:@"true"]) {
                line = [NSString stringWithFormat:@"play_se_loop(\"%@\")\r", soundEffectName];
                [outputText appendString: line];
                return;
            }
            line = [NSString stringWithFormat:@"se(\"%@\")\r", soundEffectName];
            [outputText appendString: line];
            return;
        }
        // 处理 se 背景音乐淡出
        if ([line containsString:@"@fadeoutse"]) {
            NSArray<NSString *> *array = [line componentsSeparatedByString:@" "];
            __block NSString *fadeoutTime;
            [array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj containsString:@"time"]) {
                    NSRange range = [obj rangeOfString:@"="];
                    NSString *time = [obj substringFromIndex:range.location+1];
                    fadeoutTime = time;
                }
            }];
            line = [NSString stringWithFormat:@"stop_se_loop(\"%@\")\r", soundEffectName];
            [outputText appendString: line];
            return;
        }
        // hideui
        if ([line containsString:@"@hideui"]) {
            [outputText appendString:@"hide_ui()\r"];
            return;
        }
        if ([line containsString:@"@unhideui"]) {
            [outputText appendString:@"show_ui()\r\r"];
            return;
        }
        // 淡出背景音乐
        if ([line containsString:@"@fadeoutbgm"]) {
            [outputText appendString:@"stop_bgm()\r"];
            return;
        }
        // 背景音乐
        if ([line containsString:@"@bgm"]) {
            __block NSString *bgmName;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *name = [self valueForksKey:@"storage" From:obj];
                if (name) {
                    bgmName = name;
                }
            }];
            [outputText appendFormat:@"bgm(\"%@\")\r\r", bgmName];
            return;
        }
        // 变换背景
        if ([line containsString:@"@bgtrans"]) {
            __block NSString *backgroundImageName;
            __block NSString *backgroundTransitionMethod;
            __block NSString *backgroundTransitionDuration;
            __block NSString *transitionRule;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *name = [self valueForksKey:@"storage" From:obj];
                if (name) {
                    backgroundImageName = name;
                }
                NSString *method = [self valueForksKey:@"method" From:obj];
                if (method) {
                    backgroundTransitionMethod = method;
                }
                NSString *time = [self valueForksKey:@"time" From:obj];
                if (time) {
                    backgroundTransitionDuration = time;
                }
                NSString *rule = [self valueForksKey:@"rule" From:obj];
                if (rule) {
                    transitionRule = rule;
                }
            }];
            backgroundTransitionMethod = [self luaTransitionMethodFromks:backgroundTransitionMethod];
            line = [NSString stringWithFormat:@"bg(%@,%@,%@,%@)\r", backgroundImageName, backgroundTransitionDuration, backgroundTransitionMethod, transitionRule];
            [outputText appendString:line];
            return;
        }
        
        if ([line containsString:@"@bg"]) {
            __block NSString *backgroundImageName;
            __block NSString *backgroundTransitionMethod;
            __block NSString *transitionRule;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *name = [self valueForksKey:@"storage" From:obj];
                if (name) {
                    backgroundImageName = [self removeDoubleQuates:name];
                }
                NSString *method = [self valueForksKey:@"method" From:obj];
                if (method) {
                    backgroundTransitionMethod = method;
                }
                NSString *rule = [self valueForksKey:@"rule" From:obj];
                if (rule) {
                    transitionRule = rule;
                }
            }];
            backgroundTransitionMethod = [self luaTransitionMethodFromks:backgroundTransitionMethod];
            line = [NSString stringWithFormat:@"\rhide_ui()\rbg(\"%@\",1000,%@,%@)\rshow_ui()\r", backgroundImageName,backgroundTransitionMethod.length > 0 ? backgroundTransitionMethod : @"1", transitionRule];
            [outputText appendString:line];
            return;
        }
        if ([line containsString:@"@fg"]) {
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *fgFileName = [self valueForksKey:@"storage" From:obj];
                if (fgFileName) {
                    fgName = fgFileName;
                }
            }];
            if ([fgName isEqualToString:@"none"]) {
                [outputText appendFormat:@"hide_fg(1)\r"];
            } else {
                [outputText appendFormat:@"fg(\"%@\",300,1,1)\r", fgName];
            }
        }
        if ([line containsString:@"@vo"]) {
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *voFileName = [self valueForksKey:@"storage" From:obj];
                if (voFileName) {
                    voName = voFileName;
                    // voName 要搭配下一句话
                }
            }];
        }
        if ([line containsString:@"@cg"]) {
            __block NSString *cgName;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *cgFileName = [self valueForksKey:ksFileNameKey From:line];
                if (cgFileName) {
                    cgName = cgFileName;
                }
            }];
            [outputText appendFormat:@"cg(\"%@\",1,0,0,0)\r", cgName];
        }
        if ([line containsString:@"spk"]) {
            line = [self removeSpeakerNoiseChracter:line];
            NSRange range = [line rangeOfString:@"="];
            NSString *name = [line substringFromIndex:range.location+1];
            chracterName = name;
        }
        if ([line containsString:@"[r]"]) {
            line = [self removeSpeakEndChracter:line];
            if ([chracterName containsString:@"\""]) {
                line = [NSString stringWithFormat:@"say(\"%@\")\r", line];
            } else {
                if (voName.length > 0) {
                    line = [NSString stringWithFormat:@"say(\"%@\",\"%@\",\"%@\")\r", chracterName, line, voName];
                    voName = nil;
                } else {
                    line = [NSString stringWithFormat:@"say(\"%@\",\"%@\")\r", chracterName, line];
                }
            }
            [outputText appendString:line];
            return;
        } else if (![line containsString:@"speak"] &&
                   ![line containsString:@"spk"] &&
                   ![line containsString:@"@"]){
            // 不包含 关键字，是说话的最后一行，或者没有定义角色的行
            if (line.length > 0) {
                if ([chracterName containsString:@"\""]) {
                    line = [NSString stringWithFormat:@"say(\"%@\")\r", line];
                } else if ( chracterName.length > 0) {
                    if (voName.length > 0) {
                        line = [NSString stringWithFormat:@"say(\"%@\",\"%@\",\"%@\")\r", chracterName, line, voName];
                        voName = nil;
                    } else {
                        line = [NSString stringWithFormat:@"say(\"%@\",\"%@\")\r", chracterName, line];
                    }
                } else {
                    line = [NSString stringWithFormat:@"say(\"%@\")\r", line];
                }
                [outputText appendString:line];
            } else {
                [outputText appendString:@"\r"];
            }
        }
    }];
    
    NSError *error;
    [outputText writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"Error %@", error);
    }
}

/**
 *  从一行文字中使用空格作为分隔符，然后遍历每个元素
 *
 *  @param line    需要处理的行
 *  @param handler 自行处理每个元素的 block
 */
- (void)enumerateLineObjectsFrom:(NSString *)line each:(ksEachBlock) handler {
    NSArray<NSString *> *array = [line componentsSeparatedByString:@" "];
    [array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        handler(obj);
    }];
}

/**
 *  从字符串中得到一个 ks Key 的 Value
 *
 *  @param key ks Key
 *  @param obj Value
 *
 *  @return 处理后的 Value
 */
- (NSString *)valueForksKey:(NSString *)key From:(NSString *)obj {
    if ([obj containsString:key]) {
        NSRange range = [obj rangeOfString:@"="];
        return [obj substringFromIndex:range.location+1];
    }
    return nil;
}

- (NSString *)luaTransitionMethodFromks:(NSString *)transition {
    // 参考 RuntimeEngine 指令集
    if ([transition isEqualToString:@"crossfade"]) {
        return @"2";
    }
    return nil;
}

- (NSString *)removeCommentNoise:(NSString *)comment {
    return [[[[[comment stringByReplacingOccurrencesOfString:@";" withString:@""] stringByReplacingOccurrencesOfString:@"/" withString:@""] stringByReplacingOccurrencesOfString:@"*" withString:@""] stringByReplacingOccurrencesOfString:@"[r]" withString:@""] stringByReplacingOccurrencesOfString:@"\\" withString:@""];
}

- (NSString *)removeDoubleQuates:(NSString *)string {
    return [string stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

- (NSString *)removeSpeakerNoiseChracter:(NSString *)speakerLineString {
    return [[speakerLineString stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
}

- (NSString *)removeSpeakEndChracter:(NSString *)speakText {
    return [speakText stringByReplacingOccurrencesOfString:@"[r]" withString:@""];
}

- (void)writeToPasteboard:(NSString *)string {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[string]];
}

@end
