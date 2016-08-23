//
//  RTcmixPlayer.m
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

#import "RTcmixPlayer.h"

@interface RTcmixPlayer ()
@property (readwrite)	BOOL				audioInputFlag;
@property (readwrite)	double			actualSampleRate;
@property (readwrite)	float				actualBufferSize;
@property (readwrite)	NSInteger		actualNumberOfOutputChannels;

- (void)maxBang;
- (void)maxMessage;
- (void)maxError:(const char *)message;

void interruptionListenerCallback(void *inUserData, UInt32 interruptionState);
void propListenerCallback(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize,const void *inData);
@end



// RTcmix external functions called from the RTcmixPlayer
typedef void (*RTcmixBangCallback)(void *inContext);
typedef void (*RTcmixValuesCallback)(float *values, int numValues, void *inContext);
typedef void (*RTcmixPrintCallback)(const char *printBuffer, void *inContext);

extern int	RTcmix_init();
extern int	RTcmix_setparams(float sr, int nchans, int vecsize, int recording,  int bus_count);
extern int  RTcmix_resetAudio(float sr, int nchans, int vecsize, int recording);
extern int	RTcmix_setInputBuffer(char *bufname, float *bufstart, int nframes, int nchans, int modtime);
extern void	RTcmix_setBangCallback(RTcmixBangCallback inBangCallback, void *inContext);
extern void	RTcmix_setValuesCallback(RTcmixValuesCallback inValuesCallback, void *inContext);
extern void	RTcmix_setPrintCallback(RTcmixPrintCallback inPrintCallback, void *inContext);
extern int	RTcmix_parseScore(char *thebuf, int buflen);
extern void	RTcmix_flushScore();
extern int	RTcmix_startAudio();
extern int	RTcmix_stopAudio();
extern  int RTcmix_destroy();
extern void pfield_set(int inlet, float pval);

static int		maxmessage_nvals;
static float	maxmessage_vals[1024];

static void RTcmixPlayerBangCallback(void *context)
{
	RTcmixPlayer *player = (__bridge RTcmixPlayer *) context;
	[player maxBang];
}

static void RTcmixPlayerValuesCallback(float *inValues, int numValues, void *context)
{
	RTcmixPlayer *player = (__bridge RTcmixPlayer *) context;
	maxmessage_nvals = numValues;
	for (int n = 0; n < numValues; ++n)
	{
		maxmessage_vals[n] = inValues[n];	// copy values
	}
	[player maxMessage];
}

static void RTcmixPlayerPrintCallback(const char *printBuffer, void *inContext)
{
	RTcmixPlayer *player = (__bridge RTcmixPlayer *) inContext;
	
	// check for print (with the print() commamnd) and error messages from RTcmix
	const char *pbufptr = printBuffer;
	while (strlen(pbufptr) > 0)
	{
		[player maxError:pbufptr];
		pbufptr += (strlen(pbufptr) + 1);
	}
}

@implementation RTcmixPlayer

#pragma mark Setup

- (id)init {
	if (self = [super init])
	{
		_preferredNumberOfChannels = 2;
		_preferredSampleRate = 44100.0;
		_preferredBufferSize = 1024; // increase this (in powers of 2) to improve performance (at the expense of latency)
		_avAudioSessionCategory = AVAudioSessionCategoryPlayback;
		_avAudioSessionCategoryOptions = [NSMutableArray arrayWithArray:@[[NSNumber numberWithInteger:AVAudioSessionCategoryOptionDefaultToSpeaker], [NSNumber numberWithInteger:AVAudioSessionCategoryOptionMixWithOthers]]];
	}
	return self;
}

- (void)startAudio {
	[[AVAudioSession sharedInstance] setActive:YES error:nil];

	RTcmix_init();
	RTcmix_setBangCallback(RTcmixPlayerBangCallback, (__bridge void *)(self));
	RTcmix_setValuesCallback(RTcmixPlayerValuesCallback, (__bridge void *)(self));
	RTcmix_setPrintCallback(RTcmixPlayerPrintCallback, (__bridge void *)(self));
	[self setupAudioParameters];
	RTcmix_setparams(self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag,  0);
	RTcmix_startAudio();
}

- (void)setupAudioParameters {
	
	// *** AudioSessionCatogory
	
	if ([self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryRecord] ||
		 [self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
		 [self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryMultiRoute])
	{
		self.audioInputFlag = YES;
	}
	else if ([self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryAmbient] ||
				[self.avAudioSessionCategory isEqualToString:AVAudioSessionCategorySoloAmbient] ||
				[self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryPlayback] ||
				[self.avAudioSessionCategory isEqualToString:AVAudioSessionCategoryAudioProcessing])
	{
		self.audioInputFlag = NO;
	}
	else
	{
		NSLog(@"RTcmixPlayer Error: Invalid AVAudioSessionCategory.");
	}
	
	// *** AudioSessionCatogoryOptions
	
	NSUInteger audioSessionOptions = 0;
	for (NSNumber *option in self.avAudioSessionCategoryOptions)
	{
		audioSessionOptions += option.integerValue;
	}
	
	[[AVAudioSession sharedInstance] setCategory:self.avAudioSessionCategory withOptions:audioSessionOptions error:nil];
	
	// *** Sample Rate
	
	[[AVAudioSession sharedInstance] setPreferredSampleRate:self.preferredSampleRate error:nil];
	self.actualSampleRate = [[AVAudioSession sharedInstance] sampleRate];
	
	// *** Channels
	
	[[AVAudioSession sharedInstance] setPreferredOutputNumberOfChannels:self.preferredNumberOfChannels error:nil];
	self.actualNumberOfOutputChannels = [[AVAudioSession sharedInstance] outputNumberOfChannels];

	// *** Buffer Duration/Size

	double preferredBufferDuration = (1.0 / self.actualSampleRate) * self.preferredBufferSize;
	[[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDuration error:nil];
	double actualBufferDuration = [[AVAudioSession sharedInstance] IOBufferDuration];
	self.actualBufferSize = self.actualSampleRate * actualBufferDuration;
	
	// *** Find and report to delegat any actual settings that don't match their preferred value
	NSMutableDictionary *mismatchedSettings = [[NSMutableDictionary alloc] init];
	if (self.preferredSampleRate != self.actualSampleRate)
	{
		[mismatchedSettings setObject:@[[NSNumber numberWithDouble:self.preferredSampleRate], [NSNumber numberWithDouble:self.actualSampleRate]] forKey:@"Sample Rate"];
	}
	if (self.preferredBufferSize != self.actualBufferSize)
	{
		[mismatchedSettings setObject:@[[NSNumber numberWithFloat:self.preferredBufferSize], [NSNumber numberWithFloat:self.actualBufferSize]] forKey:@"Buffer Size"];
	}
	if (self.preferredNumberOfChannels != self.actualNumberOfOutputChannels)
	{
		[mismatchedSettings setObject:@[[NSNumber numberWithInteger:self.preferredNumberOfChannels], [NSNumber numberWithInteger:self.actualNumberOfOutputChannels]] forKey:@"Number of Output Channels"];
	}
	if (self.audioInputFlag)
	{
		NSInteger actualNumberOfInputChannels = [[AVAudioSession sharedInstance] inputNumberOfChannels];
		if (self.preferredNumberOfChannels != actualNumberOfInputChannels)
		{
			[mismatchedSettings setObject:@[[NSNumber numberWithInteger:self.preferredNumberOfChannels], [NSNumber numberWithInteger:actualNumberOfInputChannels]] forKey:@"Number of Input Channels"];
		}
	}
	
	if (mismatchedSettings.count && [self.delegate respondsToSelector:@selector(audioSettingWarning:)])
	{
		[self.delegate audioSettingWarning:mismatchedSettings];
	}
	
	NSLog(@"-------------------------------");
	NSLog(@"AVAudioSession sampleRate (preferred): %f (%f)", [[AVAudioSession sharedInstance] sampleRate], self.preferredSampleRate);
	NSLog(@"AVAudioSession IOBufferDuration (preferred): %f (%f)", [[AVAudioSession sharedInstance] IOBufferDuration], preferredBufferDuration);
	NSLog(@"AVAudioSession Buffer Size (preferred): %f (%f)", self.actualBufferSize, self.preferredBufferSize);
	NSLog(@"AVAudioSession outputNumberOfChannels (preferred): %ld (%li)", (long)[[AVAudioSession sharedInstance] outputNumberOfChannels], self.preferredNumberOfChannels);
	NSLog(@"AVAudioSession inputNumberOfChannels (preferred): %ld (%li)", (long)[[AVAudioSession sharedInstance] inputNumberOfChannels], self.preferredNumberOfChannels);
	NSLog(@"-------------------------------");
}

#pragma mark Audio Utility

- (void)resetAudioParameters {
	RTcmix_flushScore();
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		RTcmix_stopAudio();
		[self setupAudioParameters];
		NSLog(@"********* Call RTcmix_resetAudio(%f   channels: %d   buffer size: %f   inputflag: %d)", self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag);
		RTcmix_resetAudio(self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag);
		RTcmix_startAudio();
	});
}

- (void)semiResetAudioParameters {
	[self setupAudioParameters];
	//NSLog(@"Audio Parameters: sample rate: %f   channels: %d   buffer size: %f   inputflag: %d", self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag);
	NSLog(@"********* Call RTcmix_resetAudio(%f   channels: %d   buffer size: %f   inputflag: %d)", self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag);
	RTcmix_resetAudio(self.actualSampleRate, (int)self.preferredNumberOfChannels, self.actualBufferSize, self.audioInputFlag);
}

- (void)pauseRTcmix {
	NSLog(@"********* Call RTcmix_stopAudio()");
	RTcmix_stopAudio();
}

- (void)resumeRTcmix {
	NSLog(@"********* Call RTcmix_startAudio()");
	RTcmix_startAudio();
}

- (void)destroyRTcmix {
	//RTcmix_flushScore();
	RTcmix_destroy();
}

- (void)maxBang {
	@autoreleasepool {
		[self.delegate maxBang];
	}
}

- (void)maxMessage {
	// maxmessage_nvals == number of elements in the returned array h
	// maxmessage_vals[] == an array of floats with the vals
	@autoreleasepool {
		NSMutableArray * maxMessage_Vals = [[NSMutableArray alloc] initWithCapacity: maxmessage_nvals];
		for (int i=0; i < maxmessage_nvals; i++)
		{
			[maxMessage_Vals addObject:[NSNumber numberWithFloat:maxmessage_vals[i]]];
		}
		[self.delegate maxMessage:maxMessage_Vals];
	}
}

- (void)maxError:(const char *)message {
	@autoreleasepool {
		[self.delegate maxError:[NSString stringWithFormat:@"%s" , message]];
		//NSLog(@"RTcmix: %@", [NSString stringWithFormat:@"%s" , message]);
	}
}

#pragma mark Score Parsing

- (void)parseScoreWithNSString:(NSString *)score {
	NSUInteger bytes = [score lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	char cScore[bytes]; 	//char cScore[32768];
	strcpy (cScore, [score UTF8String]);
	RTcmix_parseScore(cScore, (int)strlen(cScore));
}

- (void)parseScoreWithResource:(NSString *)resource ofType:(NSString *)type {
	NSString *scorePath = [[NSBundle mainBundle] pathForResource:resource ofType:type];
	NSString *score = [NSString stringWithContentsOfFile:scorePath encoding:NSUTF8StringEncoding error:nil];
	[self parseScoreWithNSString:score];
}

- (void)parseScoreWithFilePath:(NSString *)path {
	NSString *score = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	[self parseScoreWithNSString:score];
}

// stop all scheduled scripts
- (void)flushAllScores {
	RTcmix_flushScore();
}

#pragma mark Data and Communication

- (int)setSampleBuffer:(NSString *)bufferName withFilePath:(NSString *)path {
	AudioFileID     soundFile;
	AudioStreamBasicDescription		dataFormat;
	OSStatus status;
	UInt32 propsize;
	
	void *sampleBuffer;
	float *floatSampleBuffer;
	
	NSURL *soundFileURL = [NSURL fileURLWithPath:path];
	
	// BGG -- should probably use ExtAudioFileOpenURL()
	status = AudioFileOpenURL((__bridge CFURLRef)soundFileURL, kAudioFileReadPermission, kAudioFileAIFFType, &soundFile);
	if (status != 0)
	{
		NSLog(@"error opening soundfile");
		return 0;
	}
	
	propsize = sizeof(dataFormat);
	status = AudioFileGetProperty(soundFile, kAudioFilePropertyDataFormat, &propsize, &dataFormat);
	if (status != 0)
	{
		NSLog(@"problem getting AudioFile properties");
		return 0;
	}
	
	//Get file size
	UInt64 outDataSize = 0;
	propsize = sizeof(UInt64);
	AudioFileGetProperty(soundFile, kAudioFilePropertyAudioDataByteCount, &propsize, &outDataSize);
	
	//Get packet count
	UInt64 outPackets = 0;
	propsize = sizeof(UInt64);
	AudioFileGetProperty(soundFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &outPackets);
	
	UInt32 numBytes = (UInt32)outDataSize;
	UInt32 numPackets = (UInt32)outPackets;
	sampleBuffer = malloc(outDataSize);
	if (sampleBuffer == NULL)
	{
		NSLog(@"error mallocing sample buffer");
		return 0;
	}
	
	status = AudioFileReadPackets (soundFile, false, &numBytes, NULL, 0, &numPackets, sampleBuffer);
	if (status !=0)
	{
		NSLog(@"problem reading file packets into buffer");
		return 0;
	}
	
	floatSampleBuffer = malloc(numPackets*dataFormat.mChannelsPerFrame*sizeof(float));
	if (floatSampleBuffer == NULL)
	{
		NSLog(@"error mallocing fsample buffer");
		return 0;
	}
	
	// convert to floating-point buffer for RTcmix
	float *fsbptr = floatSampleBuffer;
	short *sbptr = sampleBuffer;
	for(int i = 0; i < (numPackets*dataFormat.mChannelsPerFrame); i++) {
		sbptr[i] = CFSwapInt16(sbptr[i]);
		fsbptr[i] = (float)sbptr[i]/32768.0;
	}
	
	RTcmix_setInputBuffer((char *)[bufferName UTF8String], fsbptr, numPackets, dataFormat.mChannelsPerFrame, 0);
	
	return 1;
}

- (int)setSampleBuffer:(NSString *)bufferName withResource:(NSString *)resource ofType:(NSString *)type {
	NSString *samplePath = [[NSBundle mainBundle] pathForResource:resource ofType:type];

	return [self setSampleBuffer:bufferName withFilePath:samplePath];
}

- (void) setInlet:(int)inlet withValue:(Float32)value {
	pfield_set(inlet, value);
}

#pragma mark Singleton

+(id)sharedManager {
	static dispatch_once_t pred;
	static RTcmixPlayer *sharedSingletonManager = nil;
	dispatch_once(&pred, ^{
		sharedSingletonManager = [[RTcmixPlayer alloc] init];
	});
	return sharedSingletonManager;
}

- (void) dealloc {
	abort();
}

#pragma mark Interrupt Callbacks

void interruptionListenerCallback (void *inUserData, UInt32	interruptionState) {
	RTcmixPlayer *player = (__bridge RTcmixPlayer *) inUserData;
	if (interruptionState == kAudioSessionBeginInterruption)
	{
		[player pauseRTcmix];
	}
	else if (interruptionState == kAudioSessionEndInterruption)
	{
		[player resumeRTcmix];
	}
}

void propertyListenerCallback(void								*inClientData,
										AudioSessionPropertyID		inID,
										UInt32							inDataSize,
										const void						*inData) {
	
	RTcmixPlayer *player = (__bridge RTcmixPlayer *) inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		// if there was a route change, we need to dispose the current rio unit and create a new one
		[player pauseRTcmix];
		//[player setupAudioSession];
		[player resumeRTcmix];	// TODO DAS RIGHT NOW THIS DUPLICATES SOME OF setupAudioSession
	}
}


@end
