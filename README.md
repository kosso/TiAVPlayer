# TiAVPlayer
A Titanium iOS module for playing local or remote file-based or streaming audio. Based on AVFoundation/AVPlayer. Includes seek and speed (rate) methods. WORK IN PROGRESS. 

The example/app.js contains examples of loading a remote url, a local file (.mp3) and a live radio stream url (.m3u) 
It also provides a slider for the progress and seeking.  You can also change the speed (rate) of the audio too. 

This is all very much the result of much research, reading, testing and experimentation. So please excuse the mess. 

*Reason for trying AVPlayer*

The ['AudioStreamer'](https://github.com/mattgallagher/AudioStreamer) library by Matt Gallagher is still used by Ti.Media.audioPlayer in iOS Titanium. It mostly works, but has some features missing, such as a 'seek', to move to a point in an audio file url.  A [couple](https://github.com/atsusy/tiaudiostreaming) of [attempts](https://github.com/kosso/tiaudiostreaming) have been made to implement seeking with AudioStreamer and Titanium by proxying the seekToTime method in the library in a module.  This mostly works, but the imlementations lack recent improvements to Ti.Media.audioPlayer which included an error event (finally). 

Ti.Media.audioPlayer also has a quirk on iOS where, if you play a remote mp3 file and pause it, something goes wrong with the playback after resuming, where the end of the audio is fired before it should. I'm pretty sure this is down to the use of the AudioStreamer library and the many changes to the iOS SDK since it was orginally written in 2008. The [Network Graph for AudioStreamer](https://github.com/mattgallagher/AudioStreamer/network) shows that many recent changes, updates and improvements have been made to branches of it. 

There's some discussion about the missing features on Appcelerator's Jira [TIMOB-3375](https://jira.appcelerator.org/browse/TIMOB-3375). 


Work in progress.

-----------------------

Pull requests for bugs and improvements very much accepted! 