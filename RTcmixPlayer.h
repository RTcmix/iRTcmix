//
//  RTcmixPlayer.h
//
//  Copyright 2009-2013 Brad Garton, Damon Holzborn
//
//  This file is part of iRTcmix.
//
//  iRTcmix is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, version 3 of the License.
//
//  iRTcmix is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with iRTcmix.  If not, see <http://www.gnu.org/licenses/>.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@protocol RTcmixPlayerDelegate
@optional
- (void)maxBang;
- (void)maxMessage:(NSArray *)message;
- (void)maxError:(NSString *)error;
- (void)audioSettingWarning:(NSDictionary *)warnings;
@end

@interface RTcmixPlayer : NSObject

@property (nonatomic, unsafe_unretained) NSObject <RTcmixPlayerDelegate> *delegate;

@property (nonatomic, strong)	NSString				*avAudioSessionCategory;
@property (nonatomic, strong)	NSMutableArray		*avAudioSessionCategoryOptions;
@property (readwrite)			double				preferredSampleRate;
@property (readwrite)			float					preferredBufferSize;
@property (readwrite)			NSInteger			preferredNumberOfChannels;

- (void)semiResetAudioParameters;
// Audio Utility
- (void)startAudio;
- (void)resetAudioParameters;
- (void)pauseRTcmix;
- (void)resumeRTcmix;
- (void)destroyRTcmix;

// Score Parsing
- (void)parseScoreWithNSString:(NSString *)score;
- (void)parseScoreWithFilePath:(NSString *)path;
- (void)parseScoreWithResource:(NSString *)resource ofType:(NSString *)type;
- (void)flushAllScores;

// Data and Communication
- (int)setSampleBuffer:(NSString *)bufferName withFilePath:(NSString *)path;
- (int)setSampleBuffer:(NSString *)bufferName withResource:(NSString *)resource ofType:(NSString *)type;
- (void)setInlet:(int)inlet withValue:(Float32)value;

// Singleton
+ (id)sharedManager;

@end


