//
//  NuanceWebController.mm
//  DMRecognizer
//
// Copyright 2010, Nuance Communications Inc. All rights reserved.
//
// Nuance Communications, Inc. provides this document without representation 
// or warranty of any kind. The information in this document is subject to 
// change without notice and does not represent a commitment by Nuance 
// Communications, Inc. The software and/or databases described in this 
// document are furnished under a license agreement and may be used or 
// copied only in accordance with the terms of such license agreement.  
// Without limiting the rights under copyright reserved herein, and except 
// as permitted by such license agreement, no part of this document may be 
// reproduced or transmitted in any form or by any means, including, without 
// limitation, electronic, mechanical, photocopying, recording, or otherwise, 
// or transferred to information storage and retrieval systems, without the 
// prior written permission of Nuance Communications, Inc.
// 
// Nuance, the Nuance logo, Nuance Recognizer, and Nuance Vocalizer are 
// trademarks or registered trademarks of Nuance Communications, Inc. or its 
// affiliates in the United States and/or other countries. All other 
// trademarks referenced herein are the property of their respective owners.
//

#import "NuanceWebController.h"
#import "VoiceNotifications.h"

const unsigned char SpeechKitApplicationKey[] =
{
//    0x78, 0xf5, 0x9f, 0x99, 0x7d, 0x98, 0x48, 0x15, 0x44, 0x7a,
//    0xde, 0xb4, 0x9d, 0x96, 0xa4, 0xfa, 0x35, 0x1d, 0x97, 0x14,
//    0x41, 0x63, 0x4e, 0x9f, 0xae, 0xdf, 0xfe, 0x72, 0x39, 0xb7,
//    0x8e, 0xb1, 0xac, 0x2d, 0x4a, 0x29, 0xc6, 0x92, 0x3e, 0x0a,
//    0x0c, 0x1c, 0xbf, 0xa9, 0xb2, 0x63, 0xa3, 0xe7, 0x81, 0x3b,
//    0xfb, 0xc2, 0x9e, 0x49, 0x61, 0x4c, 0x29, 0x5f, 0xbf, 0x62,
//    0x16, 0x4d, 0x13, 0xc2
    
    0x66, 0x34, 0x67, 0x7c, 0x3a, 0xbd, 0x22, 0x74, 0x4b, 0x73, 0xe0, 0xe4, 0xb8, 0x9d, 0xaa, 0x49, 0xbb, 0x43, 0x31, 0xb4, 0xb7, 0x63, 0xf3, 0xd3, 0x24, 0x32, 0x8f, 0x56, 0x40, 0xff, 0x83, 0xa6, 0x34, 0xea, 0x23, 0x6e, 0xa7, 0x45, 0xe2, 0xf2, 0xb9, 0xc3, 0xd7, 0x71, 0x60, 0x81, 0xba, 0x1c, 0xc4, 0xeb, 0xd0, 0x7c, 0x4e, 0xc3, 0x4f, 0x72, 0xf5, 0xde, 0xc9, 0x35, 0xdd, 0x4c, 0xdb, 0x11
};

@implementation NuanceWebController
@synthesize voiceSearch, vocalizer;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (id)init {
    [SpeechKit setupWithID:@"NMDPPRODUCTION_Jackson_Chen_JabberChess_20151113024014"
                      host:@"fri.nmdp.nuancemobility.net"
                      port:443
                    useSSL:NO
                  delegate:self];
    
	// Set earcons to play
	SKEarcon* earconStart	= [SKEarcon earconWithName:@"earcon_listening.wav"];
	SKEarcon* earconStop	= [SKEarcon earconWithName:@"earcon_done_listening.wav"];
	SKEarcon* earconCancel	= [SKEarcon earconWithName:@"earcon_cancel.wav"];
	
	[SpeechKit setEarcon:earconStart forType:SKStartRecordingEarconType];
	[SpeechKit setEarcon:earconStop forType:SKStopRecordingEarconType];
	[SpeechKit setEarcon:earconCancel forType:SKCancelRecordingEarconType];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doRecognition:)
                                                 name:VOICE_CAPTURE_START_NOTIFICATION
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doSpeak:)
                                                 name:VOICE_SPEAK_START_NOTIFICATION
                                               object:nil];
    
    NSLog(@"NuanceWebController initialized.");
    
    return self;
}

- (void)dealloc {
//    [voiceSearch release];
//    [super dealloc];
}

#pragma mark -
#pragma mark Actions

- (void)doRecognition: (NSNotification *) notification {
    //return if swipe again

    if (transactionState == TS_RECORDING) {
        [self.voiceSearch stopRecording];
    }
    else if (transactionState == TS_IDLE) {
        SKEndOfSpeechDetection detectionType;
        NSString* recoType;
        NSString* langType;
        
        transactionState = TS_INITIAL;

        /* 'Dictation' is selected */
//        detectionType = SKLongEndOfSpeechDetection; /* Dictations tend to be long utterances that may include short pauses. */
//        recoType = SKDictationRecognizerType; /* Optimize recognition performance for dictation or message text. */
        /* 'Search' is selected */
        detectionType = SKShortEndOfSpeechDetection; /* Searches tend to be short utterances free of pauses. */
        recoType = SKSearchRecognizerType; /* Optimize recognition performance for search text. */
	    langType = @"en_US";
		
        /* Nuance can also create a custom recognition type optimized for your application if neither search nor dictation are appropriate. */
        
        NSLog(@"doRecognition type:'%@' Language Code: '%@' using end-of-speech detection:%lu.", recoType, langType, (unsigned long)detectionType);

//        if (voiceSearch) [voiceSearch release];
//        if (self.voiceSearch) {
//            [self.voiceSearch stopRecording];
//            [self.voiceSearch cancel];
//        }
		
        voiceSearch = [[SKRecognizer alloc] initWithType:recoType
                                               detection:detectionType
                                                language:langType 
                                                delegate:self];
        NSLog(@"doRecognition voiceSearch initialized.");
    }
}

- (void)cancelDictation {
    //return if called twice
    if (self.voiceSearch) [self.voiceSearch cancel];
    
    NSLog(@"canceling dictation.");
    [SpeechKit destroy];
}

- (void)doSpeak: (NSNotification *) notification {
    NSString *textToReadString = [notification object];
    NSLog(@"doSpeak '%@'.", textToReadString);
    [self doSpeakDirect:textToReadString];
}

- (void)doSpeakDirect: (NSString *) textToReadString {
    if (isSpeaking) {
        [vocalizer cancel];
        isSpeaking = NO;
        NSLog(@"Already speaking, cancel.");
    }
    else {
        isSpeaking = YES;
        // Initializes an english voice
        vocalizer = [[SKVocalizer alloc] initWithLanguage:@"en_US" delegate:self];
        
        // Speaks the string text
        [vocalizer speakString:textToReadString];
        NSLog(@"doSpeak leaving.");
    }
}

- (BOOL)getIsSpeaking{
    return isSpeaking;
}


#pragma mark -
#pragma mark SpeechKitDelegate methods

- (void) audioSessionReleased {
    NSLog(@"audio session released");
}

- (void) destroyed {
    // Debug - Uncomment this code and fill in your app ID below, and set
    // the Main Window nib to MainWindow_Debug (in DMRecognizer-Info.plist)
    // if you need the ability to change servers in DMRecognizer
    //
    //[SpeechKit setupWithID:INSERT_YOUR_APPLICATION_ID_HERE
    //                  host:INSERT_YOUR_HOST_ADDRESS_HERE
    //                  port:INSERT_YOUR_HOST_PORT_HERE[[portBox text] intValue]
    //                useSSL:NO
    //              delegate:self];
    //
	// Set earcons to play
	//SKEarcon* earconStart	= [SKEarcon earconWithName:@"earcon_listening.wav"];
	//SKEarcon* earconStop	= [SKEarcon earconWithName:@"earcon_done_listening.wav"];
	//SKEarcon* earconCancel	= [SKEarcon earconWithName:@"earcon_cancel.wav"];
	//
	//[SpeechKit setEarcon:earconStart forType:SKStartRecordingEarconType];
	//[SpeechKit setEarcon:earconStop forType:SKStopRecordingEarconType];
	//[SpeechKit setEarcon:earconCancel forType:SKCancelRecordingEarconType];    
}

#pragma mark -
#pragma mark SKRecognizerDelegate methods

- (void)recognizerDidBeginRecording:(SKRecognizer *)recognizer
{
    NSLog(@"Recording started.");
    
    transactionState = TS_RECORDING;
//    [self performSelector:@selector(updateVUMeter) withObject:nil afterDelay:0.05];
}

- (void)recognizerDidFinishRecording:(SKRecognizer *)recognizer
{
    NSLog(@"Recording finished.");

//    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateVUMeter) object:nil];
//    [self setVUMeterWidth:0.];
    transactionState = TS_PROCESSING;
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithResults:(SKRecognition *)results
{
    NSLog(@"Got results.");
    NSLog(@"Session id [%@].", [SpeechKit sessionID]); // for debugging purpose: printing out the speechkit session id 

    long numOfResults = [results.results count];
    
    transactionState = TS_IDLE;
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    
    if (numOfResults > 0){
        NSString *firstResult = [results firstResult];
        NSLog(@"Record firstResult:'%@'.", firstResult);
        [resultArray addObject:firstResult];
    }
    if (numOfResults > 1) {
        NSString *alternatives = [[results.results subarrayWithRange:NSMakeRange(1, numOfResults-1)] componentsJoinedByString:@"\n"];
        NSLog(@"Record alternativesDisplay:'%@'.", alternatives);
        [resultArray addObject:@":"];
        [resultArray addObject:alternatives];
    }
    if (results.suggestion) {
        NSLog(@"Record Suggestion:'%@'.", results.suggestion);
        [resultArray addObject:@":"];
        [resultArray addObject:results.suggestion];
    }

    NSString *resultString = [resultArray componentsJoinedByString:@" "];
    [[NSNotificationCenter defaultCenter] postNotificationName:VOICE_CAPTURE_RESULT_NOTIFICATION object:resultString userInfo:nil];

    if (self.voiceSearch) {
        [self.voiceSearch cancel];
    }
    //    [voiceSearch release];
    voiceSearch = nil;
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithError:(NSError *)error suggestion:(NSString *)suggestion
{
    NSLog(@"Got error.");
    NSLog(@"Session id [%@].", [SpeechKit sessionID]); // for debugging purpose: printing out the speechkit session id 
    
    transactionState = TS_IDLE;
    NSLog(@"Error: [%@].", [error localizedDescription]); 

    if (suggestion) {
        NSLog(@"Record Suggestion:'%@'.", suggestion);
    }
    
//    [voiceSearch release];
    voiceSearch = nil;
}

#pragma mark -
#pragma mark SKVocalizerDelegate methods

- (void)vocalizer:(SKVocalizer *)vocalizer willBeginSpeakingString:(NSString *)text {
    isSpeaking = YES;
    if (text)
        NSLog(@"Begin read text:'%@'.", text);
    else
        NSLog(@"No text to read");
}

- (void)vocalizer:(SKVocalizer *)vocalizer willSpeakTextAtCharacter:(NSUInteger)index ofString:(NSString *)text {
    NSLog(@"Session id [%@].", [SpeechKit sessionID]); // for debugging purpose: printing out the speechkit session id
    NSLog(@"Text: '%@' at %lu.", text, (unsigned long)index);
}

- (void)vocalizer:(SKVocalizer *)vocalizer didFinishSpeakingString:(NSString *)text withError:(NSError *)error {
    NSLog(@"Done Speaking, Session id [%@].", [SpeechKit sessionID]); // for debugging purpose: printing out the speechkit session id
    isSpeaking = NO;
    if (error !=nil)
    {
        NSLog(@"Error: '%@'.", [error localizedDescription]);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:VOICE_SPEAK_LEFTOVER_NOTIFICATION object:@"" userInfo:nil];
}

@end
