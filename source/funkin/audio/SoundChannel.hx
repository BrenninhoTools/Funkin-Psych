package funkin.audio;

enum abstract SoundChannel(Int) from Int to Int
{
	var MUSIC = 0;
	var SFX = 1;
	var VOICE = 2;
}
