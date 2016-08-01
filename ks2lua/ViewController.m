//
//  ViewController.m
//  ks2lua
//
//  Created by 小笠原やきん on 7/29/16.
//  Copyright © 2016 yaqinking. All rights reserved.
//

#import "ViewController.h"
#import "NSString+ks.h"

static NSString * const ksFileNameKey = @"storage";
static NSString * const ksTimeKey = @"time";

@interface ViewController()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *sourcePathLabel;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSTextField *fileNameTextField;

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
- (IBAction)export:(id)sender {
    NSString *filePath = [NSString stringWithFormat:@"/Users/yaqinking/Downloads/Keiko/%@.lua", self.fileNameTextField.stringValue];
    [self tranlateKs:self.textView.textStorage.string saveTo:filePath];
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
                                                 [NSApp presentError:error];
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
        NSString *contentString = [NSString stringWithContentsOfFile:url.path encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"%@", error);
            [NSApp presentError:error];
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
    __block NSString *storyVoiceName;
    __block NSMutableString *outputText = [NSMutableString new];
    [linesArray enumerateObjectsUsingBlock:^(NSString * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        // 章节说明
        if ([line hasPrefix:@"*"]) {
            [outputText appendFormat:@"-- %@\r",[line stringByReplacingOccurrencesOfString:@"*" withString:@""]];
            return;
        }
        // 空行
        if ([line isEqualToString:@"[rn]"]) {
            return;
        }
        // 处理注释
        if ([line containsString:@";"]) {
            [outputText appendFormat:@"-- %@\r",[line ks_removeCommentNoise]];
            return;
        }
        // 章节名称
        if ([line containsString:@"EPingame"]) {
            NSString *epName = [line ks_removeEPNameNoise];
            [outputText appendFormat:@"chapt(\"%@\")", epName];
            return;
        }
        if ([line containsString:@"@playse"]) {
            NSArray<NSString *> *array = [line componentsSeparatedByString:@" "];
            __block NSString *loop;
            __block NSString *buf;
            [array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj containsString:@"="]) {
                    obj = [obj ks_removeDoubleQuates];
                    NSRange range = [obj rangeOfString:@"="];
                    NSString *name = [obj substringFromIndex:range.location+1];
                    if ([obj containsString:@"storage"]) {
                        soundEffectName = name;
                    } else if ([obj containsString:@"loop"]) {
                        loop = name;
                    } else if ([obj containsString:@"buf"]) {
                        NSString *tempBuf = [obj ks_valueForKey:@"buf"];
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
        // 故事书
        if ([line containsString:@"story"]) {
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *voName = [obj ks_valueForKey:ksFileNameKey];
                if (voName) {
                    storyVoiceName = voName;
                }
            }];
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
                NSString *name = [obj ks_valueForKey:ksFileNameKey];
                if (name) {
                    bgmName = name;
                }
            }];
            if (bgmName) {
                [outputText appendFormat:@"bgm(\"%@\")\r\r", bgmName];
            } else {
                [outputText appendString:@"stop_bgm()\r"];
            }
            return;
        }
        // 等待
        if ([line containsString:@"@wait"]) {
            __block NSString *waitTime;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *time = [obj ks_valueForKey:ksTimeKey];
                if (time) {
                    waitTime = time;
                }
            }];
            [outputText appendFormat:@"wait(%@)\r", waitTime];
            return;
        }
        // 跳转脚本
        if ([line containsString:@"@jump"]) {
            __block NSString *scriptName;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *fileName = [obj ks_valueForKey:ksFileNameKey];
                if (fileName) {
                    scriptName = [[fileName ks_removeDoubleQuates] stringByReplacingOccurrencesOfString:@".ks" withString:@""];
                }
            }];
            [outputText appendFormat:@"jump(\"%@\")\r", scriptName];
            return;
        }
        // 全屏叙述
        if ([line containsString:@"@eff0_0"]) {
            __block NSString *words;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *string = [obj ks_valueForKey:@"ch"];
                if (string) {
                    words = string;
                }
            }];
            [outputText appendFormat:@"story(\"%@\")\r", words];
            return;
        }
        // 变换背景
        if ([line containsString:@"@bgtrans"]) {
            __block NSString *backgroundImageName;
            __block NSString *backgroundTransitionMethod;
            __block NSString *backgroundTransitionDuration;
            __block NSString *transitionRule;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *name = [obj ks_valueForKey:ksFileNameKey];
                if (name) {
                    backgroundImageName = name;
                }
                NSString *method = [obj ks_valueForKey:@"method"];
                if (method) {
                    backgroundTransitionMethod = method;
                }
                NSString *time = [obj ks_valueForKey:ksTimeKey];
                if (time) {
                    backgroundTransitionDuration = time;
                }
                NSString *rule = [obj ks_valueForKey:@"rule"];
                if (rule) {
                    transitionRule = rule;
                }
            }];
            backgroundTransitionMethod = [backgroundTransitionMethod ks_transitionMethod];
            line = [NSString stringWithFormat:@"bg(\"%@\",%@,%@,%@)\r", backgroundImageName, backgroundTransitionDuration, backgroundTransitionMethod, transitionRule];
            [outputText appendString:line];
            return;
        }
        
        if ([line containsString:@"@bg"]) {
            __block NSString *backgroundImageName;
            __block NSString *backgroundTransitionMethod;
            __block NSString *transitionRule;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *name = [obj ks_valueForKey:ksFileNameKey];
                if (name) {
                    backgroundImageName = name;
                }
                NSString *method = [obj ks_valueForKey:@"method"];
                if (method) {
                    backgroundTransitionMethod = method;
                }
                NSString *rule = [obj ks_valueForKey:@"rule"];
                if (rule) {
                    transitionRule = rule;
                }
            }];
            backgroundTransitionMethod = [backgroundTransitionMethod ks_transitionMethod];
            line = [NSString stringWithFormat:@"\rhide_ui()\rbg(\"%@\",1000,%@,%@)\rshow_ui()\r", backgroundImageName,backgroundTransitionMethod.length > 0 ? backgroundTransitionMethod : @"1", transitionRule.length > 0 ? transitionRule : @"1"];
            [outputText appendString:line];
            return;
        }
        if ([line containsString:@"@fg"]) {
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *fgFileName = [obj ks_valueForKey:ksFileNameKey];
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
                NSString *voFileName = [obj ks_valueForKey:ksFileNameKey];
                if (voFileName) {
                    voName = voFileName;
                    // voName 要搭配下一句话
                }
            }];
        }
        /**
         cg(name,group,time,mode,rule)
         参数说明:
         name:CG的名字
         group:CG的ID（用来解锁CG，每张CG都有唯一ID）
         time:完成切换CG需要的时间
         mode:切换模式（0:直接切换，1:遮罩切换，2:淡入，3:淡出）
         rule:遮罩规则（对应rule下的遮罩png）
         指令例子:
         cg("CG_1_1",1,0,0,0)--直接显示CG_1_1
         cg("CG_2_1",2,200,1,"24")--通过遮罩24在200秒内显示CG_2_1
         */
        if ([line containsString:@"@cg"]) {
            __block NSString *cgName;
            __block NSString *duration;
            [self enumerateLineObjectsFrom:line each:^(NSString *obj) {
                NSString *cgFileName = [obj ks_valueForKey:ksFileNameKey];
                if (cgFileName) {
                    cgName = cgFileName;
                }
                NSString *time = [obj ks_valueForKey:ksTimeKey];
                if (time) duration = time;
            }];
            [outputText appendFormat:@"cg(\"%@\",1,%@,0,0)\r", cgName, duration];
        }
        if ([line containsString:@"spk"]) {
            line = [line ks_removeSpeakerNoiseChracter];
            NSRange range = [line rangeOfString:@"="];
            NSString *name = [line substringFromIndex:range.location+1];
            chracterName = name;
        }
        if ([line containsString:@"[r]"]) {
            line = [line ks_removeSpeakEndChracter];
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
                    if (storyVoiceName.length > 0) {
                        line = [NSString stringWithFormat:@"say(\" \",\"%@\",\"%@\")\r", line, storyVoiceName];
                        storyVoiceName = nil;
                    } else {
                        line = [NSString stringWithFormat:@"say(\"%@\")\r", line];
                    }
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
//                [outputText appendString:@"\r"];
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


- (void)writeToPasteboard:(NSString *)string {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[string]];
}

@end
