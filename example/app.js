

// Example use of TiAVPlayer to play remote audio. 

// Author : Kosso

Ti.Media.audioSessionCategory = Ti.Media.AUDIO_SESSION_CATEGORY_PLAYBACK;
//Be sure to also set background audio in tiapp.xml if you want it to play when sent to background.



// open a single window
var window = Ti.UI.createWindow({
  backgroundColor:'white'
});

var scroller = Ti.UI.createScrollView({top:20, left:0, right:0, zIndex:1, bottom:0, contentHeight:Ti.UI.SIZE, scrollType:'vertical', layout:'vertical'});

var TiAVPlayer = require('com.kosso.tiavplayer');

var avplayer = TiAVPlayer.createPlayer();

// set the audio url (wait for playerstatuschange event)

// Remote: test
avplayer.url = "https://archive.org/download/testmp3testfile/mpthreetest.mp3";

// Local file (add a test to the Resources folder) : avplayer.url = "file://"+Ti.Filesystem.resourcesDirectory + "test.mp3";

var is_paused = false;
var seeking = false;

var avplayer_player_state = [
  'STATE_UNKNOWN',
  'STATE_READY',
  'STATE_WAITING_FOR_DATA',
  'STATE_PLAYING',
  'STATE_PAUSED',
  'STATE_STOPPING',
  'STATE_STOPPED',
  'STATE_SEEKING',
  'STATE_SEEKING_COMPLETE',
  'STATE_FAILED'
];

var avplayer_status_strings = [
  'STATUS_UNKNOWN',
  'STATUS_READY_TO_PLAY',
  'STATUS_FAILED'
];



avplayer.addEventListener('durationavailable', function(e){

  console.log('durationavailable');
  //console.log(e);
  prog.text = msecsToSecsAndMinutes(e.source.time) + ' / ' + msecsToSecsAndMinutes(e.duration);

});


avplayer.addEventListener('error', function(e){
	console.log('!!!!!  avplayer ERROR event!');

	//console.log(e);
	//console.log(e.source.status);
	msg.text = avplayer_status_strings[e.status];
	prog.text = "--:-- / --:--";
	alert('error!\n\n'+e.message);

	slider.enabled = false;

});

avplayer.addEventListener('complete', function(e){
	console.log('avplayer COMPLETE event!');
	console.log(e);

	msg.text = avplayer_player_state[e.source.state];
	prog.text = '00:00 / '+msecsToSecsAndMinutes(avplayer.duration);
	slider.value = 0;

	avplayer.stop();

});

avplayer.addEventListener('playerstatuschange', function(e){
	// readiness to play status
	console.log('player status change: '+e.status);
	console.log(avplayer_status_strings[e.status]);
	msg.text = avplayer_status_strings[e.status];
	prog.text = "--:-- / --:--";

	if(e.status==1){
		slider.enabled = true;
	} else {
		slider.enabled = false;
	}

});

avplayer.addEventListener('change', function(e){
	// playback state
	console.log('player state change: '+e.state);
	console.log(avplayer_player_state[e.state])
	msg.text = avplayer_player_state[e.state];

	if(e.state==3 || e.state==4){
		slider.enabled = true;
	} else {
		slider.enabled = false;
	}

});

avplayer.addEventListener('seekcomplete', function(e){
	// seek has completed
	seeking = false;
	avplayer.play();
});

avplayer.addEventListener('progress', function(e){
	// e.time
	// e.duration
  	if(seeking===true){
  		return;
  	}
   	prog.text = msecsToSecsAndMinutes(e.time) + ' / ' + msecsToSecsAndMinutes(e.duration);
   	slider.value = Math.round((e.time / e.duration)*100);
});


var start = Ti.UI.createButton({
	top:20,
	height:40,
	title:'play'
});
start.addEventListener('click', function(e){
	
	avplayer.start();
	is_paused = false;
	pause.title = 'pause';
});


var pause = Ti.UI.createButton({
  top:10,
  height:40,
  title:'pause'
});
pause.addEventListener('click', function(e){

  if(is_paused===false){
    avplayer.pause();
    is_paused = true;
    pause.title = 'resume';
  } else {
    avplayer.start(); // unpauses 
    is_paused = false;
    pause.title = 'pause';
  }
});

var stop = Ti.UI.createButton({
  top:10,
  height:40,
  title:'stop'
});
stop.addEventListener('click', function(e){

	console.log('STOP: playing: '+avplayer.playing+' - paused: '+avplayer.paused);

	avplayer.stop();
	
	prog.text = '00:00 / '+msecsToSecsAndMinutes(avplayer.duration);
	slider.value = 0;

});


var msg = Ti.UI.createLabel({
	text:' - ',
	top:10,
	width:Ti.UI.SIZE
});

var prog = Ti.UI.createLabel({
	text:'--:-- / --:--',
	top:10,
	width:Ti.UI.SIZE
});

var slider = Titanium.UI.createSlider({
	top: 10,
	min: 0,
	max: 100,
	left: 20,
	right: 20,
	value: 0
});

slider.addEventListener('start', function(e){
	seeking = true;
});

slider.addEventListener('stop', function(e){
	//seeking = false; will be set by the seekcomplete event
	var new_time = parseFloat(avplayer.duration * (e.value / 100) );
	console.log('seek to new time : '+new_time);

	avplayer.seek(new_time);

});

scroller.add(start);
scroller.add(stop);
scroller.add(pause);
scroller.add(msg);
scroller.add(prog);

scroller.add(slider);

var seeker = Ti.UI.createButton({
  top:10,
  height:40,
  title:'seek to 5 seconds'
});

seeker.addEventListener('click', function(e){
	// seekThenPlay(ms) will automatically play after seeking. Otherwise use the avplayer.seek(ms) method and wait for the 'seekcomplete' event.
	avplayer.seekThenPlay(parseFloat(5000));
});

scroller.add(seeker);

var faster = Ti.UI.createButton({
  top:10,
  height:40,
  title:'play double speed'
});

faster.addEventListener('click', function(e){
	avplayer.speed(2);
});

scroller.add(faster);


var normal = Ti.UI.createButton({
  top:0,
  height:40,
  title:'play normal speed'
});

normal.addEventListener('click', function(e){
	avplayer.speed(1);
});

scroller.add(normal);

var slower = Ti.UI.createButton({
  top:0,
  height:40,
  title:'play half speed'
});

slower.addEventListener('click', function(e){
	avplayer.speed(0.5);
});

scroller.add(slower);


var newtune = Ti.UI.createButton({
  top:10,
  height:40,
  title:'set new tune url then play'
});

newtune.addEventListener('click', function(e){

	is_paused = false;
	slider.value = 0;
	prog.text = '--:-- / --:--';
	avplayer.url = "http://users.skynet.be/fa046054/home/P22/track37.mp3"; // Via : http://www.testsounds.com/
	msg.text = avplayer_player_state[avplayer.state];

	avplayer.addEventListener('playerstatuschange', tuneReadyToPlay);

});
function tuneReadyToPlay(e){
	avplayer.removeEventListener('playerstatuschange', tuneReadyToPlay);
	avplayer.start();
}

scroller.add(newtune);

var start_radio = Ti.UI.createButton({
  top:10,
  height:40,
  title:'set live radio then play'
});

start_radio.addEventListener('click', function(e){

	slider.value = 0;
	prog.text = '--:-- / --:--';
	avplayer.url = "http://www.listenlive.eu/bbcradio1.m3u"; // BBC Radio 1 : Url via : http://www.listenlive.eu/uk.html
	msg.text = avplayer_player_state[avplayer.state];

	avplayer.addEventListener('playerstatuschange', readyToPlayLive);

});

function readyToPlayLive(e){
	avplayer.removeEventListener('playerstatuschange', readyToPlayLive);
	avplayer.play(); // play not start here.. for now
	msg.text = 'PLAYING_STREAM';
	prog.text = 'streaming';
	slider.enabled = false;
	slider.value = 0;
}

scroller.add(start_radio);


var bogus = Ti.UI.createButton({
  top:10,
  height:40,
  bottom:40,
  title:'set bogus audio url'
});

bogus.addEventListener('click', function(e){

	slider.value = 0;
	prog.text = '--:-- / --:--';
	avplayer.url = "file:///error.mp3";
	// should fire the 'error' event.
	msg.text = avplayer.state;
});

scroller.add(bogus);



window.add(scroller);

window.open();


// Utilities

function msecsToSecsAndMinutes(msecs, show_msecs, show_hours, show_long){
  show_msecs = show_msecs || false;
  show_hours = show_hours || false;
  show_long = show_long || false;
  var msSecs = (1000);
  var msMins = (msSecs * 60);
  var msHours = (msMins * 60);
  var numHours = Math.floor(msecs/msHours);
  var numMins = Math.floor((msecs - (numHours * msHours)) / msMins);
  var numSecs = Math.floor((msecs - (numHours * msHours) - (numMins * msMins))/ msSecs);
  var numMillisecs = ((msecs - (numHours * msHours) - (numMins * msMins) - (numSecs * msSecs)) / 10).toFixed();
  if(numMillisecs==100){
    numMillisecs = 0;
  }
  var longString = "";
  if (numHours > 0){;
    if (numHours < 10 && !show_long){;
      numHours = "0" + numHours;
    }
    var hs = 's';
    if(numHours==1 || numHours=='01'){hs='';}
    longString = numHours + " hour"+hs;
    numHours = numHours + ":";
  } else {
    numHours = "";
    longString = "";
    if(show_hours){
      numHours = "00:";
    }
  }
  if (numMins < 10 && !show_long){
    numMins = "0" + numMins;
  }
  if(numMins > 0){
    if(longString!=''){
     longString += ', ';
    }
    var ms = 's';
    if(show_long && numSecs > 30){
      numMins++;
    }
    if(numMins==1 || numMins=='01'){ms='';}

    longString += numMins + ' minute'+ms;
  }
  if (numSecs < 10 && !show_long){;
    numSecs = "0" + numSecs;
  }
  if (numMillisecs < 10 && !show_long){
    numMillisecs = "0" + numMillisecs;
  } 
  var msec = '';
  if(show_msecs){
      msec = '.'+numMillisecs;
  }
  var resultString = numHours + numMins + ":" + numSecs  + msec;
  if(show_long){
    return longString;
  } else {
    return resultString;
  }
}
