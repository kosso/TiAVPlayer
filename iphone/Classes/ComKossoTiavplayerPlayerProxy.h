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
    BOOL *isStream;                 // for live radio. disables durationavailable
    double time;                    // current time
    float rate;
 
}
@property (nonatomic, readwrite, assign) float rate;
@property (nonatomic, readwrite, assign) double duration;
@property (nonatomic, readwrite, assign) double time;
@property (nonatomic, readwrite, assign) int status;
@property (nonatomic, readwrite, assign) int state;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL buffering;


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
