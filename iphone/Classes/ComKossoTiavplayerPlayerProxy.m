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
 I do not know how to properly code Objective-C!  But through a lot of trial and error, I seem to have the basics working. I'm learning!
 
 There are probably loads of rookie mistakes that I've made, or gone totally the wrong way about some things.
 There may also be things missing to create full parity with the Android Ti.Media.audioPlayer. But it's mostly there now.
 
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
@synthesize streaming;
@synthesize buffering;
@synthesize rate;
@synthesize time;
@synthesize pausedForAudioSessionInterruption;
@synthesize live_flag;



-(void)dealloc
{
    if(avPlayer!=nil){
        if([avPlayer currentItem] != nil){
            //NSLog(@"[INFO] DEALLOC remove item observers");
            //[avPlayer.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"status"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferFull"];
            [avPlayer.currentItem.asset removeObserver:self forKeyPath:@"duration"];
        }
        //NSLog(@"[INFO] avPlayer DEALLOCATING NOW");
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [avPlayer release];
    }
    // release any resources that have been retained by the module
    [super dealloc];
}

-(void)destroy:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self destroy:args];}, YES);
        return;
    }
    @synchronized(self){
        //NSLog(@"[INFO] avPlayer : DESTROY!");
        
        // do I need to reset the BOOL flags too? streaming, playing etc?
        
        if(progressUpdateTimer!=nil){
             //NSLog(@"[INFO] avPlayer : RELEASE TIMER!");
            [progressUpdateTimer invalidate];
            RELEASE_TO_NIL(progressUpdateTimer);
        }
        if(avPlayer!=nil){
            if(playing){
                //NSLog(@"[INFO] forcing stop");
                avPlayer.rate = 0.0f;
                playing = NO;
            }
            if([avPlayer currentItem] != nil){
                //NSLog(@"[INFO] remove item observers");
                //[avPlayer.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
                [avPlayer.currentItem removeObserver:self forKeyPath:@"status"];
                [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
                [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
                [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferFull"];
                [avPlayer.currentItem.asset removeObserver:self forKeyPath:@"duration"];
                // NSLog(@"[INFO] remove notifications");
                [[NSNotificationCenter defaultCenter] removeObserver:self];
            }
            
            RELEASE_TO_NIL(avPlayer);
           
            
        }
        RELEASE_TO_NIL(url);
        live_flag = NO;
        streaming = NO;
    }
}


- (void)updateDuration
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self updateDuration];}, YES);
        return;
    }
    durationavailable = YES;
    duration = round(CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000.0f);
    //NSLog(@"[INFO] avPlayer updateDuration : duration : %@", NUMDOUBLE(duration));
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fireDurationChangeEvent:duration];
    });
}

- (void)setUrl:(id)value
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self setUrl:value];}, YES);
        return;
    }
    
    ENSURE_SINGLE_ARG(value, NSString);
    url = [value retain];
    NSString *escapedValue =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(nil,
                                                         (CFStringRef)url,
                                                         NULL,
                                                         NULL,
                                                         kCFStringEncodingUTF8) autorelease];
    //NSLog(@"[INFO] avPlayer : setUrl : %@", url);

    // Stop if needed
    if(avPlayer!=nil){
        
        if(playing){
            [progressUpdateTimer invalidate];
            RELEASE_TO_NIL(progressUpdateTimer);

            //NSLog(@"[INFO] forcing stop");
            avPlayer.rate = 0.0f;
            playing = NO;
        }
        if([avPlayer currentItem] != nil){
            //[avPlayer.currentItem removeObserver:self forKeyPath:@"timedMetadata"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"status"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
            [avPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferFull"];
            [avPlayer.currentItem.asset removeObserver:self forKeyPath:@"duration"];
        }
    }
    RELEASE_TO_NIL(avPlayer);
    streaming = NO;
    live_flag = NO;
    duration = 0;
    durationavailable = NO;
    time = 0;
    
    status = AV_PLAYER_STATUS_UNKNOWN;
    state = STATE_STARTING;
    lastPlayerState = state;
    
    if([escapedValue length] == 0){
        //NSLog(@"[INFO] avPlayer : URL WAS NIL. stop here. ");
        return;
    }
    
    // Attempts to override the AVAssetURL loading headers.. Not having much luck. Could be a 'private' API.
    // NSMutableDictionary * headers = [NSMutableDictionary dictionary];
    // [headers setObject:@"Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.0; SV1; AmazingAppsiOS 1.0.0)" forKey:@"User-Agent"];
    // AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:escapedValue] options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
    
    /*
    // https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/02_Playback.html
    // If an asset is not possible, it could be a live stream. So this method should fail.
    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:escapedValue] options:nil];
    // not behaving as expected/understood.
    if(asset.tracks!=nil){
        NSLog(@"[INFO] AV ASSET LOADED OK");
    } else {
        NSLog(@"[INFO] AV ASSET LOOKS LIKE A LIVE ONE!");
    }
    
    AVPlayerItem * item = [AVPlayerItem playerItemWithAsset:asset];
    avPlayer = [[AVPlayer alloc] initWithPlayerItem:item];
    */
    
    // or load the url to the AVPlayer directly
    avPlayer = [[AVPlayer alloc] initWithURL:[NSURL URLWithString:escapedValue]];
    

    // Notify end of audio file.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[avPlayer currentItem]];
    
    // Notify audio interruption. eg: Siri, alarm, calls.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    
    // Notify if audio ends for other reason than ending. eg: network dropout.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:[avPlayer currentItem]];

    // Notify media server reset
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaServerDidReset:)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:nil];

    // Notify media server lost/ended.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaServerDidEnd:)
                                                 name:AVAudioSessionMediaServicesWereLostNotification
                                               object:nil];

    
    // KVO for player readyiness status after setting item asset url.
    [avPlayer.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
    // KVO for timed metadata. Live streams can send out this data.  This is not for ID3 tags. I need to figure that out.
    //[avPlayer.currentItem addObserver:self forKeyPath:@"timedMetadata" options:nil context:nil];
    // KVO For buffering..
    [avPlayer.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [avPlayer.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [avPlayer.currentItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew context:nil];
    [avPlayer.currentItem.asset addObserver:self forKeyPath:@"duration" options:NSKeyValueObservingOptionInitial context:nil];

}



- (void)mediaServerDidEnd:(NSNotification *)notification
{
    NSLog(@"[INFO] avPlayer : DID THE SERVER GO AWAY ? : mediaServerDidEnd notification ");
    
    [progressUpdateTimer invalidate];
    RELEASE_TO_NIL(progressUpdateTimer);
    
    
    state = STATE_INTERRUPTED;
    lastPlayerState = state;
    paused = NO;
    playing = NO;
    // fire the complete event
    [self fireCompleteEvent];
    
}



- (void)mediaServerDidReset:(NSNotification *)notification
{
    NSLog(@"[INFO] avPlayer : DID THE SERVER RESET ? : mediaServerDidReset notification ");
    
    [progressUpdateTimer invalidate];
    RELEASE_TO_NIL(progressUpdateTimer);
    
    state = STATE_INTERRUPTED;
    lastPlayerState = state;
    paused = NO;
    playing = NO;
    // fire the complete event
    [self fireCompleteEvent];
    
    //[self destroy:YES];
}



- (void)playerItemFailedToPlayToEndTime:(NSNotification *)notification
{
    // This can happen when the network drops out.
    NSLog(@"[INFO] avPlayer : DID THE NETWORK DROP OUT? : playerItemFailedToPlayToEndTime notification ");
    [progressUpdateTimer invalidate];
    RELEASE_TO_NIL(progressUpdateTimer);
    
    state = STATE_INTERRUPTED;
    lastPlayerState = state;

    paused = NO;
    playing = NO;
    // fire the complete event
    [self fireCompleteEvent];
    
    //[self destroy:YES];
}


- (void)playerItemDidReachEnd:(NSNotification *)notification
{
   // NSLog(@"[INFO] avPlayer ended ");
    
    [progressUpdateTimer invalidate];
    RELEASE_TO_NIL(progressUpdateTimer);
    
    
    // set time back to zero
    [avPlayer.currentItem seekToTime: kCMTimeZero];

    
    state = STATE_STOPPING;
    lastPlayerState = state;
    paused = NO;
    playing = NO;
    // fire the complete event
     //NSLog(@"[INFO] avPlayer fire complete event ");
    [self fireCompleteEvent];
    // NSLog(@"[INFO] avPlayer call stop ");
    [self stop:YES];
    
}


- (void)audioSessionInterrupted:(NSNotification *)notification
{
    int interruptionType = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    if (interruptionType == AVAudioSessionInterruptionTypeBegan && !pausedForAudioSessionInterruption) {
        NSLog(@"[INFO] avPlayer : Audio session was interrupted");
        if (playing == YES || paused == YES || buffering == YES) {
            NSLog(@"[INFO] avPlayer : Pausing for audio session interruption");
            pausedForAudioSessionInterruption = YES;
            [self pause:YES];
        }
    } else if (interruptionType == AVAudioSessionInterruptionTypeEnded && avPlayer!=nil) {
        //NSLog(@"[INFO] avPlayer : Audio session interruption has ended");
        if ([notification.userInfo[AVAudioSessionInterruptionOptionKey] intValue] == AVAudioSessionInterruptionOptionShouldResume) {
            if (pausedForAudioSessionInterruption) {
                //NSLog(@"[INFO] avPlayer : Resuming after audio session interruption");
                [self play:YES];
            }
        }
        pausedForAudioSessionInterruption = NO;
    }
}

// KVO
// example : http://stackoverflow.com/questions/24969523/simple-kvo-example

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == avPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
        
        //NSLog(@"[INFO] KVO avPlayer.currentItem status changed : %d", avPlayer.currentItem.status);
        
        if (avPlayer.currentItem.status == AVPlayerStatusReadyToPlay) {
            // NSLog(@"[INFO] KVO avPlayer set status : AV_PLAYER_STATUS_READY_TO_PLAY");
            status = AV_PLAYER_STATUS_READY_TO_PLAY;
            state = STATE_INITIALIZED;
            lastPlayerState = state;
            
        } else if (avPlayer.currentItem.status == AVPlayerStatusUnknown) {
            // NSLog(@"[INFO] KVO avPlayer set status : AV_PLAYER_STATUS_UNKNOWN");
            status = AV_PLAYER_STATUS_UNKNOWN;
        } else if (avPlayer.currentItem.status == AVPlayerStatusFailed) {
            // something went wrong. avPlayer.error should contain some information
            //NSLog(@"[INFO] KVO avPlayer set status AV_PLAYER_STATUS_FAILED");
            status = AV_PLAYER_STATUS_FAILED;
            state = STATE_FAILED;
            lastPlayerState = state;
            
            // fire an error event
            [self fireErrorEvent:avPlayer.currentItem.error];
            
            // cleanup
            [self destroy:YES];

            return;
        }
        
        @synchronized(self){
            if ([self _hasListeners:@"playerstatuschange"]) {
                NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                                       NUMINT(state),              @"state",
                                       NUMINT(status),              @"status",
                                       self,                        @"source",
                                       @"playerstatuschange",         @"type",nil];
                [self fireEvent:@"playerstatuschange" withObject:event];
            }
        }
        
    } else if (object == avPlayer.currentItem && [keyPath isEqualToString:@"playbackBufferEmpty"]) {
        //NSLog(@"[INFO] avPlayer BUFFERING");
        buffering = YES;
    } else if (object == avPlayer.currentItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        //NSLog(@"[INFO] avPlayer LIKELY NOT BUFFERING");
        buffering = NO;
    } else if (object == avPlayer.currentItem && [keyPath isEqualToString:@"playbackBufferFull"]) {
        //NSLog(@"[INFO] avPlayer BUFFER IS FULL");
        buffering = NO;
    } else if (object == avPlayer.currentItem.asset && [keyPath isEqualToString:@"duration"]) {
        
         @synchronized(self){
             if( CMTimeCompare(avPlayer.currentItem.asset.duration, kCMTimeIndefinite) == 0){
                 //NSLog(@"[INFO] avPlayer.currentItem.asset.duration is INFINITE! IS IT A LIVE STREAM??");
                 streaming = YES;
             } else {
                // Update the duration and fire event
                [self updateDuration];
            }
        }
    } /* else if ([keyPath isEqualToString:@"timedMetadata"]) {
        
        NSLog(@"[INFO] currentItem timedMetadata!!");
        AVPlayerItem* _playerItem = object;

         for (AVMetadataItem* metadata in _playerItem.timedMetadata)
         {
            NSLog(@"[INFO] timedMetadata: key: %@\nkeySpace: %@\ncommonKey: %@\nvalue: %@", [metadata.key description], metadata.keySpace, metadata.commonKey, metadata.stringValue);
         }
         //NSArray *mmetadata = [_playerItem.asset metadata]; // iOS 8+
         
         NSArray *mmetadata = [_playerItem.asset commonMetadata];
         for ( AVMetadataItem* item in mmetadata ) {
             NSString *key = [item commonKey];
             NSString *value = [item stringValue];
             NSLog(@"[INFO] commonMetadata: key = %@, value = %@", key, value);
         }
        NSArray *etadata = [_playerItem.asset metadata];
        for ( AVMetadataItem* item in etadata ) {
            NSString *key = [item commonKey];
            NSString *value = [item stringValue];
            NSLog(@"[INFO] metadata: key = %@, value = %@", key, value);
        }
    } */
    
}

/*
 
// untested enhancements
 
- (NSTimeInterval) availableDurationNSTimeInterval
{
    // returns the available NSTimeInterval (double) duration of an audio file loading from a url
    NSArray *loadedTimeRanges = [[avPlayer currentItem] loadedTimeRanges];
    // This is an array and could be discontinuous, but let's just look at the top one.
    // We could dig deeper into the array and return provide ability to know if a requested time is seekable, for example.
    CMTimeRange timeRange = [[loadedTimeRanges objectAtIndex:0] CMTimeRangeValue];
    Float64 startSeconds = CMTimeGetSeconds(timeRange.start);
    Float64 durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;
    return result;
}

- (CMTime)availableDurationCMTime
{
    // returns the available CMTime duration of an audio file loading from a url
    // This is an array and could be discontinuous, but let's just look at the top one.
    NSValue *range = avPlayer.currentItem.loadedTimeRanges.firstObject;
    if (range != nil){
        return CMTimeRangeGetEnd(range.CMTimeRangeValue);
    }
    return kCMTimeZero;
}
*/


- (void)start:(id)args
{

    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self start:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to start");
        return;
    }
    
    //NSLog(@"[INFO] avPlayer : start calling play on main thread");
    @synchronized(self)
    {
        [self play:args];
    }
}

-(void)play:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self play:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to play");
        return;
    }
    
    @synchronized(self)
    {
        
       // NSLog(@"[INFO] avPlayer : play : start timer");
        progressUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
                                                                target:self
                                                              selector:@selector(updateProgress:)
                                                              userInfo:nil
                                                               repeats:YES] retain];
        
        //NSLog(@"[INFO] avPlayer : play!");
    
        [avPlayer play];
        paused = NO;
        playing = YES;
    }
}

- (void)stop:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self stop:args];}, YES);
        return;
    }

    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to stop");
        return;
    }
    
    @synchronized(self)
    {
        
        [avPlayer setRate:0.0f]; // effectively stop.
        [avPlayer seekToTime: kCMTimeZero
             toleranceBefore: kCMTimeZero
              toleranceAfter: kCMTimeZero
           completionHandler: ^(BOOL finished) {
               //NSLog(@"[INFO] avPlayer stopped and re-wound ");
               
               [progressUpdateTimer invalidate];
               RELEASE_TO_NIL(progressUpdateTimer);
               
               state = STATE_STOPPED;
               playing = NO;
               paused = NO;
               live_flag = NO;
               lastPlayerState = state;
                //NSLog(@"[INFO] avPlayer firing stopped event ");
               [self fireStateChangeEvent:lastPlayerState];
           }
         ];
    }
}


- (void)pause:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self pause:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to pause");
        return;
    }
    @synchronized(self)
    {
        [avPlayer pause];
        [progressUpdateTimer invalidate];
        RELEASE_TO_NIL(progressUpdateTimer);
        
        state = STATE_PAUSED;
        playing = NO;
        paused = YES;
        lastPlayerState = state;
        [self fireStateChangeEvent:lastPlayerState];
        
    }
}

- (void)speed:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self speed:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to speed");
        return;
    }
    rate = [TiUtils floatValue:[args objectAtIndex:0]];
    avPlayer.rate = rate;
}

// could test for available seek time ranges : https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVPlayerItem_Class/index.html#//apple_ref/occ/instp/AVPlayerItem/seekableTimeRanges


- (void)seek:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self seek:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to seek");
        return;
    }
    @synchronized(self)
    {
        state = STATE_SEEKING;
        lastPlayerState = state;
        buffering = YES;
        [avPlayer pause];
        playing = NO;
        [progressUpdateTimer invalidate];
        RELEASE_TO_NIL(progressUpdateTimer);
        [self fireStateChangeEvent:lastPlayerState];
        
        // milliseconds are sent for compatibility with Android Ti.Media.audioPlayer
        float seconds = [TiUtils floatValue:[args objectAtIndex:0]];
        seconds /= 1000;
        //NSLog(@"[INFO] SEEK request to : %f", seconds);
        CMTime cmTime = CMTimeMake(seconds, 1); // timescale is 1
        
        if(CMTIME_IS_VALID(cmTime)){
            [avPlayer.currentItem seekToTime: cmTime
             //   toleranceBefore: kCMTimeZero
             //    toleranceAfter: kCMTimeZero
                           completionHandler: ^(BOOL finished) {
                               state = STATE_SEEKING_COMPLETE;
                               lastPlayerState = state;
                               buffering = NO;

                               [self fireSeekCompleteEvent];
                           }
             ];
        }
    }
}

- (void)seekThenPlay:(id)args
{
    if (![NSThread isMainThread]) {
        TiThreadPerformOnMainThread(^{[self seekThenPlay:args];}, YES);
        return;
    }
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to seekThenPlay");
        return;
    }
    @synchronized(self)
    {
        [avPlayer pause];
        playing = NO;
        [progressUpdateTimer invalidate];
        RELEASE_TO_NIL(progressUpdateTimer);

        // milliseconds are sent for compatibility with Android Ti.Media.audioPlayer
        float seconds = [TiUtils floatValue:[args objectAtIndex:0]];
        seconds /= 1000;
        //NSLog(@"[INFO] SEEK request to : %f", seconds);
        CMTime cmTime = CMTimeMake(seconds, 1); // timescale is 1 for seconds
        state = STATE_WAITING_FOR_DATA;
        lastPlayerState = state;
        buffering = YES;
        if(CMTIME_IS_VALID(cmTime)){
            [avPlayer.currentItem seekToTime: cmTime
             //   toleranceBefore: kCMTimeZero
             //    toleranceAfter: kCMTimeZero
                           completionHandler: ^(BOOL finished) {
                               state = STATE_SEEKING_COMPLETE;
                               lastPlayerState = state;
                               buffering = NO;
                               [self fireSeekCompleteEvent];
                               [self play:YES];
                           }
             ];
        }
    }
}

- (void)updateProgress:(NSTimer *)updateTimer
{

    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to updateProgress");
        return;
    }
    // Note : If AVPlayerItem.presentationSize.width and height are zero, it's not a video.
    
    // return;
    
    if (avPlayer.rate != 0.0f)
    {
        @synchronized(self)
        {
            
            
            
            if( CMTimeCompare(avPlayer.currentItem.asset.duration, kCMTimeIndefinite) == 0 && live_flag == NO){
                // Duration is 'Indefinite' until it's known.
                // A duration of kCMTimeIndefinite is reported for live streaming

                //NSLog(@"[INFO] LOOKS LIKE A STREAM");
                playing = YES;
                paused = NO;
                buffering = NO;
                state = STATE_PLAYING;
                lastPlayerState = state;
                streaming = YES;
                live_flag = YES;
                
                [self fireStateChangeEvent:state];
                
                return;
            }
            
            if ( CMTimeGetSeconds(avPlayer.currentItem.asset.duration)  > 0  && durationavailable && streaming == NO)
            {
                double currentProgress = round(CMTimeGetSeconds(avPlayer.currentTime) * 1000.0f);
                
                if(currentProgress != time){
                    playing = YES;
                    paused = NO;
                    buffering = NO;
                    state = STATE_PLAYING;
                    time = currentProgress; // rounded ms, like Android
                    
                    // fire progress event
                    [self fireProgressEvent:time];
                }
                
            }
            
            /*
            if(streaming == YES && live_flag == NO){
                NSLog(@"[INFO] avPlayer : WE GOT A LIVE ONE!!!!!!  : %d", streaming);
                state = STATE_PLAYING;
                //lastPlayerState = state;
                live_flag = YES; // set once
                [self fireStateChangeEvent:state];
                return;
                
            }
             */
            if(state != lastPlayerState && avPlayer.currentItem.status == AVPlayerStatusReadyToPlay && live_flag==NO){
                lastPlayerState = state;
                //NSLog(@"[INFO] avPlayer : state changed in updateProgress timer. fire change event");
                [self fireStateChangeEvent:lastPlayerState];
            }
            

        }
    }
    
}

-(void)fireSeekCompleteEvent
{
    if ([self _hasListeners:@"seekcomplete"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(YES),       @"complete",
                               NUMDOUBLE(round(CMTimeGetSeconds(avPlayer.currentItem.currentTime) * 1000)),    @"time",
                               NUMDOUBLE(round(CMTimeGetSeconds(avPlayer.currentItem.asset.duration) * 1000)),    @"duration",
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
                               NUMBOOL(YES),        @"success",
                               NUMINT(0),   @"code", // Android compat
                               @"complete",   @"type",nil];
        [self fireEvent:@"complete" withObject:event];
    }
}

-(void)fireDurationChangeEvent:(double)value
{
    // audio player to the end.
    if ([self _hasListeners:@"durationchange"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMDOUBLE(round(value)), @"duration", // Rounded ms like Android.
                               NUMDOUBLE(round(time)), @"time",
                               self,		@"source",
                               NUMINT(state),   @"state",
                               @"durationchange",   @"type",nil];
        [self fireEvent:@"durationchange" withObject:event];
    }
}

-(void)fireStateChangeEvent:(int)value
{
    if ([self _hasListeners:@"change"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMINT(value),       @"state",
                               NUMBOOL(streaming),        @"streaming",
                               self,		@"source",
                               @"change",   @"type",nil];
        [self fireEvent:@"change" withObject:event];
    }
}

-(void)fireProgressEvent:(double)value
{
    if(avPlayer==nil){
        //NSLog(@"[INFO] avPlayer : nothing to fireProgressEvent");
        return;
    }
    
    
   // NSLog(@"[INFO] progressEvent: value : %d", value);
    
   //  NSLog(@"[INFO] progressEvent: state : %d", state);
    
    
    if ([self _hasListeners:@"progress"]) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               //NUMINT(state), @"state",
                               NUMDOUBLE(round(value)),      @"progress", // Android compat.  // Android: rounded ms.
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
