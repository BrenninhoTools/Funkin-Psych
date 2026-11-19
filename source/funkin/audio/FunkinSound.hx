package funkin.audio;

import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import openfl.media.Sound;

class FunkinSound extends FlxSound
{
	public static var musicVolume(default, set):Float = 1;
	public static var sfxVolume(default, set):Float = 1;
	public static var voiceVolume(default, set):Float = 1;
	public static var currentMusicKey(default, null):String = null;

	public var channel(default, set):SoundChannel = SFX;
	public var key(default, null):String = null;

	public function new()
	{
		super();
	}

	public static function channelVolume(channel:SoundChannel):Float
	{
		return switch (channel)
		{
			case MUSIC: musicVolume;
			case VOICE: voiceVolume;
			default: sfxVolume;
		}
	}

	public static function getAsset(key:String, channel:SoundChannel = SFX):Sound
	{
		if (key == null) return null;
		return channel == MUSIC ? Paths.music(key) : Paths.sound(key);
	}

	public static function load(key:String, channel:SoundChannel = SFX, volume:Float = 1, looped:Bool = false, autoDestroy:Bool = true, autoPlay:Bool = false, ?group:FlxSoundGroup, ?onComplete:Void->Void):FunkinSound
	{
		var asset:Sound = getAsset(key, channel);
		if (asset == null) return null;
		return fromSound(asset, key, channel, volume, looped, autoDestroy, autoPlay, group, onComplete);
	}

	public static function fromSound(asset:Sound, ?key:String, channel:SoundChannel = SFX, volume:Float = 1, looped:Bool = false, autoDestroy:Bool = true, autoPlay:Bool = false, ?group:FlxSoundGroup, ?onComplete:Void->Void):FunkinSound
	{
		var sound:FunkinSound = cast FlxG.sound.list.recycle(cast FunkinSound);
		sound.loadEmbedded(asset, looped, autoDestroy, onComplete);
		sound.key = key;
		sound.channel = channel;
		sound.volume = volume;
		if (group == null) group = channel == MUSIC ? FlxG.sound.defaultMusicGroup : FlxG.sound.defaultSoundGroup;
		group.add(sound);
		if (autoPlay) sound.play();
		return sound;
	}

	public static function playOnce(key:String, volume:Float = 1, ?onComplete:Void->Void):FunkinSound
		return load(key, SFX, volume, false, true, true, null, onComplete);

	public static function playVoice(key:String, volume:Float = 1, ?onComplete:Void->Void):FunkinSound
		return load(key, VOICE, volume, false, true, true, null, onComplete);

	public static function playMusic(key:String, volume:Float = 1, looped:Bool = true, ?fadeInDuration:Float, restartIfPlaying:Bool = true):FunkinSound
	{
		var current:FlxSound = FlxG.sound.music;
		if (!restartIfPlaying && current != null && current.playing && currentMusicKey == key)
			return Std.isOfType(current, FunkinSound) ? cast current : null;

		var asset:Sound = getAsset(key, MUSIC);
		if (asset == null) return null;

		var music:FunkinSound = Std.isOfType(current, FunkinSound) ? cast current : null;
		if (current != null && music == null)
		{
			current.stop();
			FlxG.sound.defaultMusicGroup.remove(current);
			current.destroy();
		}
		if (music == null) music = new FunkinSound();
		else if (music.active) music.stop();

		music.loadEmbedded(asset, looped);
		music.key = key;
		music.channel = MUSIC;
		music.persist = true;
		FlxG.sound.defaultMusicGroup.add(music);
		FlxG.sound.music = music;
		currentMusicKey = key;

		if (fadeInDuration != null && fadeInDuration > 0)
		{
			music.volume = 0;
			music.play();
			music.fadeIn(fadeInDuration, 0, volume);
		}
		else
		{
			music.volume = volume;
			music.play();
		}
		return music;
	}

	public static function stopMusic(?fadeOutDuration:Float)
	{
		var music:FlxSound = FlxG.sound.music;
		if (music == null) return;
		if (fadeOutDuration != null && fadeOutDuration > 0)
			music.fadeOut(fadeOutDuration, 0, function(_) music.stop());
		else
			music.stop();
		currentMusicKey = null;
	}

	public static function stopAll(includeMusic:Bool = false)
	{
		for (sound in FlxG.sound.list)
			if (sound != null && sound.exists) sound.stop();
		if (includeMusic) stopMusic();
	}

	public static function pauseAll(includeMusic:Bool = true)
	{
		for (sound in FlxG.sound.list)
			if (sound != null && sound.playing) sound.pause();
		if (includeMusic && FlxG.sound.music != null && FlxG.sound.music.playing) FlxG.sound.music.pause();
	}

	public static function resumeAll(includeMusic:Bool = true)
	{
		for (sound in FlxG.sound.list)
			if (sound != null && sound.exists && !sound.playing && sound.time > 0) sound.resume();
		if (includeMusic && FlxG.sound.music != null && !FlxG.sound.music.playing) FlxG.sound.music.resume();
	}

	static function refreshVolumes()
	{
		@:privateAccess
		{
			for (sound in FlxG.sound.list)
				if (sound != null) sound.updateTransform();
			if (FlxG.sound.music != null) FlxG.sound.music.updateTransform();
		}
	}

	static function set_musicVolume(value:Float):Float
	{
		musicVolume = FlxMath.bound(value, 0, 1);
		refreshVolumes();
		return musicVolume;
	}

	static function set_sfxVolume(value:Float):Float
	{
		sfxVolume = FlxMath.bound(value, 0, 1);
		refreshVolumes();
		return sfxVolume;
	}

	static function set_voiceVolume(value:Float):Float
	{
		voiceVolume = FlxMath.bound(value, 0, 1);
		refreshVolumes();
		return voiceVolume;
	}

	function set_channel(value:SoundChannel):SoundChannel
	{
		channel = value;
		updateTransform();
		return channel;
	}

	override function calcTransformVolume():Float
		return super.calcTransformVolume() * channelVolume(channel);

	override public function destroy()
	{
		key = null;
		super.destroy();
	}
}
