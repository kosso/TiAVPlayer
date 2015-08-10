/**
 * TiAVPlayer
 *
 
 A Titanium module for (hopefully) better audioplayer control than the current Ti.Media.audioPlayer, since it's based on very old code.
 
 This attempt is based on AVFoundation/AVPlayer.
 
 - com.kosso.tiavplayer
 - version  : 0.1
 - Author   : Kosso
 - Date     : August 6, 2015.
 
 - Disclaimer :
 I do not know how to properly code Objective-C!  But through a lot of trial and error, I seem to have the basics working.
 
 There's probably loads of rookie mistakes that I've made, or gone totally the wrong way about some things.
 There will also be things missing to create parity from the Android Ti.Media.audioPlayer.
 Feel free to fork and submit pull requests for bugs and improvements.
 
 
 - THIS IS A WORK IN PROGRESS!
 
 - NOT PRODUCTION READY
 
 - IT'S A MESS DOWN THERE
 
 **/

#import "ComKossoTiavplayerPlayerProxy.h"

@implementation ComKossoTiavplayerPlayerProxy

@synthesize duration;
@synthesize status;
@synthesize state;
@synthesize playing;
@synthesize paused;
@synthesize rate;
@synthesize time;

#define AV_PLAYER_STATE_UNKNOWN 0;
#define AV_PLAYER_STATE_READY 1;
#define AV_PLAYER_STATE_WAITING_FOR_DATA 2;
#define AV_PLAYER_STATE_PLAYING 3;
#define AV_PLAYER_STATE_PAUSED 4;
#define AV_PLAYER_STATE_STOPPING 5;
#define AV_PLAYER_STATE_STOPPED 6;
#define AV_PLAYER_STATE_SEEKING 7;
#define AV_PLAYER_STATE_SEEKING_COMPLETE 8;
#define AV_PLAYER_STATE_FAILED 9;

#define AV_PLAYER_STATUS_UNKNOWN 0;
#define AV_PLAYER_STATUS_READY_TO_PLAY 1;
#define AV_PLAYER_STATUS_FAILED 2;


-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [avPlayer release];
    // release any resources that have been retained by the module
    [super dealloc];
}

- (void)stopWatchingForChangesTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [progressUpdateTimer invalidate];
        RELEASE_TO_NIL(progressUpdateTimer);
        
    });
    
}
- (void)startWatchingForChangesTimer
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        progressUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
                                                                target:self
                                                              selector:@selector(updateProgress:)
                                                              userInfo:nil
                                                               repeats:YES] retain];
    });
    
}

- (void)setUrl:(id)value
{
    
    // What to do if sent NULL. Maybe stop and tear it down.
    isStream = NO;
    duration = 0;
    durationavailable = NO;
    
    ENSURE_SINGLE_ARG(value, NSString);
    
    url = [value retain];
    
    NSString *escapedValue =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(nil,
                                                         (CFStringRef)url,
                                                         NULL,
                                                         NULL,
                                                         kCFStringEncodingUTF8) autorelease];
    NSLog(@"[INFO] avPlayer setUrl : %@", url);
    
    
    // Stop if needed
    if(avPlayer!=nil){
        [self stopWatchingForChangesTimer];
        if(playing){
            NSLog(@"[INFO] forcing stop");
            avPlayer.rate = 0.0f;
            playing = NO;
        }
        
        
        if([avPlayer currentItem] != nil){
            [avPlayer.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        }
        
    }
    RELEASE_TO_NIL(avPlayer);
    
    status = AV_PLAYER_STATUS_UNKNOWN;
    state = AV_PLAYER_STATE_UNKNOWN;
    /*
    NSMutableDictionary * headers = [NSMutableDictionary dictionary];
    [headers setObject:@"KossoTiAVPlayerModule" forKey:@"User-Agent"];
    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:escapedValue] options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
    AVPlayerItem * item = [AVPlayerItem playerItemWithAsset:asset];
    avPlayer = [[AVPlayer alloc] initWithPlayerItem:item];
    */
    NSDictionary *dictionary =
    [[NSDictionary alloc] initWithObjectsAndKeys:
     @"Your desired user agent", @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    [dictionary release];


    //if(!avPlayer){
    avPlayer = [[AVPlayer alloc] initWithURL:[NSURL URLWithString:escapedValue]];
    //} else {
    //    [avPlayer replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:escapedValue]]];
    //}
    // Could do this instead of teardown/recreate..
    
    // (re)start a timer to check progress
    
    // start the timer to check for changes/progress, etc.
    [self startWatchingForChangesTimer];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[avPlayer currentItem]];
    
    [avPlayer.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [avPlayer.currentItem addObserver:self forKeyPath:@"timedMetadata" options:nil context:nil];
    
}

// KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == avPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        
        //NSLog(@"[INFO] KVO avPlayer.currentItem status changed : %d", avPlayer.currentItem.status);
        
        if (avPlayer.currentItem.status == AVPlayerStatusReadyToPlay) {
            // NSLog(@"[INFO] KVO avPlayer set status : AV_PLAYER_STATUS_READY_TO_PLAY");
            status = AV_PLAYER_STATUS_READY_TO_PLAY;
        } else if (avPlayer.currentItem.status == AVPlayerStatusUnknown) {
            // NSLog(@"[INFO] KVO avPlayer set status : AV_PLAYER_STATUS_UNKNOWN");
            status = AV_PLAYER_STATUS_UNKNOWN;
        } else if (avPlayer.currentItem.status == AVPlayerStatusFailed) {
            // something went wrong. avPlayer.error should contain some information
            //NSLog(@"[INFO] KVO avPlayer set status AV_PLAYER_STATUS_FAILED");
            status = AV_PLAYER_STATUS_FAILED;
            state = AV_PLAYER_STATE_FAILED;
            // fire an error event
            [self fireErrorEvent:avPlayer.currentItem.error];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"status"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            
            return;
        }
        
        @synchronized(self){
            
            if ([self _hasListeners:@"playerstatuschange"]) {
                NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                                       NUMINT(status),              @"status",
                                       self,                        @"source",
                                       @"playerstatuschange",         @"type",nil];
                [self fireEvent:@"playerstatuschange" withObject:event];
            }
        }
        
        /*
         if(NUMINT(avPlayer.status)!=lastPlayerReadyStatus && avPlayer.status!=AVPlayerStatusFailed){
         NSLog(@"[INFO] avPlayer status changed");
         NSLog(@"[INFO] status: %d", avPlayer.status);
         lastPlayerReadyStatus = NUMINT(avPlayer.status);
         status = lastPlayerReadyStatus;
         
         //if(avPlayer.status == AVPlayerStatusReadyToPlay){
         //    status = AV_PLAYER_STATE_READY;
         //}
         
         @synchronized(self){
         
         if ([self _hasListeners:@"readystatuschange"]) {
         NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
         lastPlayerReadyStatus,              @"status",
         self,                    @"source",
         @"readystatuschange",         @"type",nil];
         [self fireEvent:@"readystatuschange" withObject:event];
         }
         }
         }
         */
        
        
        
    } else
        if ([keyPath isEqualToString:@"timedMetadata"])
        {
            NSLog(@"[INFO] currentItem timedMetadata!!");
            
            
            AVPlayerItem* _playerItem = object;
            
            
            
             for (AVMetadataItem* metadata in _playerItem.timedMetadata)
             {
             NSLog(@"[INFO] \nkey: %@\nkeySpace: %@\ncommonKey: %@\nvalue: %@", [metadata.key description], metadata.keySpace, metadata.commonKey, metadata.stringValue);
             }
             
            
             //NSArray *mmetadata = [_playerItem.asset metadata]; // iOS 8+
             
             NSArray *mmetadata = [_playerItem.asset commonMetadata];
             for ( AVMetadataItem* item in mmetadata ) {
             NSString *key = [item commonKey];
             NSString *value = [item stringValue];
             NSLog(@"[INFO] METADATA : key = %@, value = %@", key, value);
             }
            
            
        }
    
}

/*
 - (void)readyStatusUpdate
 {
 
 if(NUMINT(avPlayer.status)!=lastPlayerReadyStatus){
 NSLog(@"[INFO] readyStatusUpdate: %d", avPlayer.status);
 //NSLog(@"[INFO] ASSET : %@", avPlayer.currentItem.asset);
 
 lastPlayerReadyStatus = NUMINT(avPlayer.status);
 status = lastPlayerReadyStatus;
 
 if(avPlayer.status == AVPlayerStatusReadyToPlay){
 status = AV_PLAYER_STATE_READY;
 // Oddly, even when I give this a dummy url, it still gives AVPlayerStatusReadyToPlay ?
 // However, the AVAsset will be null.
 if(avPlayer.currentItem.asset==nil){
 NSLog(@"[INFO] ASSET IS NULL!");
 status = AV_PLAYER_STATUS_FAILED;
 lastPlayerReadyStatus = NUMINT(status);
 }
 }
 
 @synchronized(self){
 
 if ([self _hasListeners:@"readystatuschange"]) {
 NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
 lastPlayerReadyStatus,             @"status",
 self,                        @"source",
 @"readystatuschange",        @"type",nil];
 [self fireEvent:@"readystatuschange" withObject:event];
 }
 }
 }
 }
 */


- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    NSLog(@"[INFO] avPlayer ended ");
    
    //[self stopWatchingForChangesTimer];
    
    state = AV_PLAYER_STATE_READY;
    //lastPlayerReadyStatus = nil;
    //lastPlayerState = nil;
    
    paused = NO;
    playing = NO;
    
    // fire the complete event
    [self fireCompleteEvent];
    
}


- (void)start:(id)args
{
    
    [self stopWatchingForChangesTimer];
    [self startWatchingForChangesTimer];
    
    @synchronized(self)
    {
        //   dispatch_sync(dispatch_get_main_queue(), ^{
        [self play:args];
        paused = NO;
        //playing = YES;
        //  });
    }
}

-(void)play:(id)args
{
    @synchronized(self)
    {
        [avPlayer play];
        paused = NO;
        playing = YES;
    }
}

- (void)stop:(id)args
{
    
    @synchronized(self)
    {
        [avPlayer setRate:0.0f]; // effectively stop.
        [avPlayer seekToTime: kCMTimeZero
             toleranceBefore: kCMTimeZero
              toleranceAfter: kCMTimeZero
           completionHandler: ^(BOOL finished) {
               //NSLog(@"[INFO] avPlayer stopped and rewound ");
               state = AV_PLAYER_STATE_STOPPED;
               playing = NO;
               paused = NO;
           }
         ];
    }
}


- (void)pause:(id)args
{
    @synchronized(self)
    {
        [avPlayer pause];
        paused = YES;
    }
}

- (void)speed:(id)args
{
    rate = [TiUtils floatValue:[args objectAtIndex:0]];
    avPlayer.rate = rate;
}

// could test for available seek time ranges : https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVPlayerItem_Class/index.html#//apple_ref/occ/instp/AVPlayerItem/seekableTimeRanges

- (void)seek:(id)args
{
    @synchronized(self)
    {
        state = AV_PLAYER_STATE_SEEKING;
        
        [avPlayer pause];
        playing = NO;
        // milliseconds are sent for compatibility with Android Ti.Media.audioPlayer
        float seconds = [TiUtils floatValue:[args objectAtIndex:0]];
        seconds /= 1000;
        //NSLog(@"[INFO] SEEK request to : %f", seconds);
        CMTime cmTime = CMTimeMake(seconds, 1);
        
        if(CMTIME_IS_VALID(cmTime)){
            dispatch_sync(dispatch_get_main_queue(), ^{
                [avPlayer.currentItem seekToTime: cmTime
                 //   toleranceBefore: kCMTimeZero
                 //    toleranceAfter: kCMTimeZero
                               completionHandler: ^(BOOL finished) {
                                   state = AV_PLAYER_STATE_SEEKING_COMPLETE;
                                   [self fireSeekCompleteEvent];
                               }
                 ];
            });
        }
    }
}

- (void)seekThenPlay:(id)args
{
    [avPlayer pause];
    playing = NO;
    // milliseconds are sent for compatibility with Android Ti.Media.audioPlayer
    float seconds = [TiUtils floatValue:[args objectAtIndex:0]];
    seconds /= 1000;
    //NSLog(@"[INFO] SEEK request to : %f", seconds);
    CMTime cmTime = CMTimeMake(seconds, 1);
    state = AV_PLAYER_STATE_SEEKING;
    if(CMTIME_IS_VALID(cmTime)){
        dispatch_sync(dispatch_get_main_queue(), ^{
            [avPlayer.currentItem seekToTime: cmTime
             //   toleranceBefore: kCMTimeZero
             //    toleranceAfter: kCMTimeZero
                           completionHandler: ^(BOOL finished) {
                               state = AV_PLAYER_STATE_SEEKING_COMPLETE;
                               [self fireSeekCompleteEvent];
                               [self play:YES];
                           }
             ];
        });
    }
}

- (void)updateProgress:(NSTimer *)updateTimer
{
    
    // return;
    
    if (avPlayer.rate != 0.0f)
    {
        @synchronized(self)
        {
            if( CMTimeCompare(avPlayer.currentItem.asset.duration, kCMTimeIndefinite) == 0 && !durationavailable ){
                // Duration is 'Indefinite' until it's known.
                
                // A duration of kCMTimeIndefinite is reported for live streaming
                // NSLog(@"[INFO] no duration available yet");

                return;
            } else {
                if(!durationavailable){
                    
                    
                    // MOVE THIS TO AN OBSERVER ON currentItem.duration?
                    // then change to "durationchange"?  (Will this change/grow when buffering?)
                    
                    
                    
                    // OK. Let's fire the duationavailable event and set the flag.
                    durationavailable = YES;
                    // Update the duration
                    duration = (CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000.0f);
                    // Create the event data
                    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                                           NUMDOUBLE(CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000), @"duration",
                                           self,                                                                    @"source",
                                           url,                                                                     @"url",
                                           @"durationavailable",                                                    @"type",nil];
                    // Fire the event if there's a listener for it.
                    if ([self _hasListeners:@"durationavailable"]) {
                        [self fireEvent:@"durationavailable" withObject:event];
                    }
                }
            }
            
            
            if ( CMTimeGetSeconds(avPlayer.currentItem.asset.duration)  > 0  && durationavailable)
            {
                double currentProgress = CMTimeGetSeconds(avPlayer.currentItem.currentTime);
                
                if(currentProgress != time){
                    playing = YES;
                    paused = NO;
                    state = AV_PLAYER_STATE_PLAYING;
                    time = currentProgress;
                    [self fireProgressEvent:time];
                }
                
            }
            
            if(state != lastPlayerState){
                lastPlayerState = state;
                [self fireStateChangeEvent:lastPlayerState];
            }
        }
    } else {
        if(paused){
            state = AV_PLAYER_STATE_PAUSED;
        } else if(stopped){
            state = AV_PLAYER_STATE_STOPPED;
        }
        if(state != lastPlayerState){
            // NSLog(@"[INFO] status has changed %d", status);
            lastPlayerState = state;
            [self fireStateChangeEvent:lastPlayerState];
        }
    }
}

-(void)fireSeekCompleteEvent
{
    if ([self _hasListeners:@"seekcomplete"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(YES),       @"complete",
                               NUMDOUBLE(CMTimeGetSeconds(avPlayer.currentItem.currentTime) * 1000),    @"time",
                               NUMDOUBLE(CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000),    @"duration",
                               self,		@"source",
                               @"seekcomplete",   @"type",nil];
        [self fireEvent:@"seekcomplete" withObject:event];
    }
}


-(void)fireCompleteEvent
{
    // audio player to the end.
    if ([self _hasListeners:@"complete"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               self,		@"source",
                               NUMINT(state),   @"state",
                               @"complete",   @"type",nil];
        [self fireEvent:@"complete" withObject:event];
    }
}

-(void)fireStateChangeEvent:(int)value
{
    if ([self _hasListeners:@"change"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMINT(value),       @"state",
                               self,		@"source",
                               @"change",   @"type",nil];
        [self fireEvent:@"change" withObject:event];
    }
}

-(void)fireProgressEvent:(double)value
{
    if ([self _hasListeners:@"progress"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMDOUBLE(value * 1000),      @"time",
                               NUMDOUBLE(CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000),    @"duration",
                               self,					               @"source",
                               @"progress",                            @"type",nil];
        [self fireEvent:@"progress" withObject:event];
    }
}

-(void)fireErrorEvent:(NSError*)error
{
    if ([self _hasListeners:@"error"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               error.localizedDescription, @"message",
                               NUMINT(status), @"status",
                               NUMINT(state), @"state",
                               self,		@"source",
                               @"error",   @"type",nil];
        [self fireEvent:@"error" withObject:event];
    }
}

@end
