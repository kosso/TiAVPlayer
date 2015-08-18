/**
 
 TiAVPlayer : A Titanium module for (hopefully) better audioplayer control than the current
 Ti.Media.audioPlayer, since it's based on very old code.
 
 - Author   : Kosso
 - Date     : August 6, 2015.
 
 - Disclaimer : I do not know how to properly code Objective-C!  But through a lot of trail and error, I got this far!
 
 - THIS IS A WORK IN PROGRESS!
 
**/

#import "TiProxy.h"
#import "TiUtils.h"
#import <AVFoundation/AVFoundation.h>

@interface ComKossoTiavplayerPlayerProxy : TiProxy {
    
    AVPlayer *avPlayer;             // The AVPlayer
    NSString *url;                  // the url to the audio
    NSTimer *progressUpdateTimer;
    BOOL playing;
    BOOL buffering;
    BOOL paused;
    BOOL stopped;
    BOOL durationavailable;         // flag so it only fires once
    int lastPlayerState;          // playback state
    NSNumber *lastPlayerReadyStatus;    // player status
    BOOL streaming;                 // for live radio. disables durationavailable
    BOOL live_flag;
    // double time;                    // current time
    float rate;
    BOOL pausedForAudioSessionInterruption;
 
}

/*
Ti.Media.audioPlayer on Android is:
 
0	@Kroll.constant public static final int STATE_BUFFERING = TiSound.STATE_BUFFERING;
1	@Kroll.constant public static final int STATE_INITIALIZED = TiSound.STATE_INITIALIZED;
2	@Kroll.constant public static final int STATE_PAUSED = TiSound.STATE_PAUSED;
3	@Kroll.constant public static final int STATE_PLAYING = TiSound.STATE_PLAYING;
4	@Kroll.constant public static final int STATE_STARTING = TiSound.STATE_STARTING;
5	@Kroll.constant public static final int STATE_STOPPED = TiSound.STATE_STOPPED;
6	@Kroll.constant public static final int STATE_STOPPING = TiSound.STATE_STOPPING;
7	@Kroll.constant public static final int STATE_WAITING_FOR_DATA = TiSound.STATE_WAITING_FOR_DATA;
8	@Kroll.constant public static final int STATE_WAITING_FOR_QUEUE = TiSound.STATE_WAITING_FOR_QUEUE;
 
*/

#define STATE_BUFFERING 0;
#define STATE_INITIALIZED 1;
#define STATE_PAUSED 2;
#define STATE_PLAYING 3;
#define STATE_STARTING 4;
#define STATE_STOPPED 5;
#define STATE_STOPPING 6;
#define STATE_WAITING_FOR_DATA 7;
#define STATE_WAITING_FOR_QUEUE 8;
#define STATE_FAILED 9; // Not on Android
#define STATE_INTERRUPTED 10; // Not on Android
#define STATE_SEEKING 11; // Not on Android
#define STATE_SEEKING_COMPLETE 12; // Not on Android
 
#define AV_PLAYER_STATUS_UNKNOWN 0;
#define AV_PLAYER_STATUS_READY_TO_PLAY 1;
#define AV_PLAYER_STATUS_FAILED 2;


@property (nonatomic, readwrite, assign) float rate;
@property (nonatomic, readwrite, assign) double duration;
@property (nonatomic, readwrite, assign) double time;
@property (nonatomic, readwrite, assign) int status;
@property (nonatomic, readwrite, assign) int state;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL buffering;
@property (nonatomic, assign) BOOL live_flag;
@property (nonatomic, assign) BOOL streaming;
@property (nonatomic, assign) BOOL pausedForAudioSessionInterruption;



@property(nonatomic, readonly) NSError *error;

- (void)destroy:(id)args;
- (void)start:(id)args;
- (void)play:(id)args;
- (void)stop:(id)args;
- (void)pause:(id)args;
- (void)seek:(id)args;
- (void)seekThenPlay:(id)args;
- (void)speed:(id)args;


@end
