package funkin.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import miniaudio.MiniAudio;

typedef MixerChannel =
{
	var name:String;
	var color:Int;
}

class AudioMixer
{
	public static final CHANNELS:Array<MixerChannel> = [
		{name: 'Music', color: 0x4FC3F7},
		{name: 'Vocals', color: 0x81C784},
		{name: 'SFX', color: 0xFFB74D},
		{name: 'Master', color: 0xFFFFFF}
	];

	public static var windowSeconds:Float = 0.025;
	public static var streamEstimate:Float = 0.5;

	public static function sample(?into:Array<Float>):Array<Float>
	{
		var levels:Array<Float> = into != null ? into : [0, 0, 0, 0];
		var music:FlxSound = FlxG.sound.music;
		var voices:Array<FlxSound> = vocalSounds();

		var musicLevel:Float = measure(music);
		var vocalLevel:Float = 0;
		for (voice in voices) vocalLevel = Math.max(vocalLevel, measure(voice));

		var sfxLevel:Float = 0;
		if (FlxG.sound.list != null)
			for (sound in FlxG.sound.list.members)
				if (sound != null && sound != music && !voices.contains(sound)) sfxLevel = Math.max(sfxLevel, measure(sound));

		var master:Float = FlxG.sound.muted ? 0 : FlxG.sound.volume;
		levels[0] = musicLevel;
		levels[1] = vocalLevel;
		levels[2] = sfxLevel;
		levels[3] = Math.min(1, Math.max(musicLevel, Math.max(vocalLevel, sfxLevel)) * master);
		return levels;
	}

	static function vocalSounds():Array<FlxSound>
	{
		var result:Array<FlxSound> = [];
		var game:funkin.play.PlayState = funkin.play.PlayState.instance;
		if (game != null && FlxG.state == game)
		{
			if (game.vocals != null) result.push(game.vocals);
			if (game.opponentVocals != null) result.push(game.opponentVocals);
		}
		else
		{
			if (funkin.ui.freeplay.FreeplayState.vocals != null) result.push(funkin.ui.freeplay.FreeplayState.vocals);
			if (funkin.ui.freeplay.FreeplayState.opponentVocals != null) result.push(funkin.ui.freeplay.FreeplayState.opponentVocals);
		}
		return result;
	}

	public static function measure(sound:FlxSound):Float
	{
		if (sound == null || !sound.exists || !sound.playing) return 0;
		return Math.min(1, peak(sound) * sound.getActualVolume());
	}

	public static function peak(sound:FlxSound):Float
	{
		#if (lime && !html5)
		var openflSound:openfl.media.Sound = @:privateAccess sound._sound;
		if (openflSound == null) return 0;
		var buffer:lime.media.AudioBuffer = @:privateAccess openflSound.__buffer;
		if (buffer == null || buffer.data == null || buffer.sampleRate <= 0 || buffer.channels <= 0) return streamEstimate;
		var view:lime.utils.ArrayBufferView = buffer.data;
		var window:Int = Std.int(Math.max(1, buffer.sampleRate * windowSeconds));
		var frame:Int = Std.int(sound.time / 1000 * buffer.sampleRate);
		return MiniAudio.bufferPeak(view.buffer, view.byteOffset, view.byteLength, buffer.bitsPerSample, buffer.channels, frame - window, window);
		#else
		return streamEstimate;
		#end
	}
}
