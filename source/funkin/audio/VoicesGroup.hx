package funkin.audio;

import flixel.sound.FlxSound;
import openfl.media.Sound;

class VoicesGroup
{
	public var player(default, null):Array<FlxSound> = [];
	public var opponent(default, null):Array<FlxSound> = [];

	public var volume(default, set):Float = 1;
	public var pitch(default, set):Float = 1;
	public var playerVolume(default, set):Float = 1;
	public var opponentVolume(default, set):Float = 1;
	public var time(get, set):Float;
	public var playing(get, never):Bool;

	public function new() {}

	public function addPlayer(?sound:Sound, ?existing:FlxSound):FlxSound
	{
		var track:FlxSound = existing != null ? existing : FunkinSound.fromSound(sound, null, VOICE, 1, false, false);
		if (track == null) return null;
		player.push(track);
		applyVolume(track, playerVolume);
		track.pitch = pitch;
		return track;
	}

	public function addOpponent(?sound:Sound, ?existing:FlxSound):FlxSound
	{
		var track:FlxSound = existing != null ? existing : FunkinSound.fromSound(sound, null, VOICE, 1, false, false);
		if (track == null) return null;
		opponent.push(track);
		applyVolume(track, opponentVolume);
		track.pitch = pitch;
		return track;
	}

	public function forEach(callback:FlxSound->Void)
	{
		for (track in player) if (track != null) callback(track);
		for (track in opponent) if (track != null) callback(track);
	}

	public function play(?startTime:Float)
	{
		forEach(function(track) {
			if (startTime != null) track.time = startTime;
			track.play();
		});
	}

	public function pause()
		forEach(function(track) track.pause());

	public function resume()
		forEach(function(track) track.resume());

	public function stop()
		forEach(function(track) track.stop());

	public function resync(songTime:Float, tolerance:Float = 20):Bool
	{
		var fixed:Bool = false;
		forEach(function(track) {
			if (!track.playing || track.length <= 0 || songTime >= track.length) return;
			if (Math.abs(track.time - songTime) > tolerance)
			{
				track.time = songTime;
				fixed = true;
			}
		});
		return fixed;
	}

	public function destroy()
	{
		forEach(function(track) {
			track.stop();
			FlxG.sound.list.remove(track, true);
			track.destroy();
		});
		player = [];
		opponent = [];
	}

	function applyVolume(track:FlxSound, groupVolume:Float)
		track.volume = volume * groupVolume;

	function get_time():Float
	{
		for (track in player) if (track != null) return track.time;
		for (track in opponent) if (track != null) return track.time;
		return 0;
	}

	function set_time(value:Float):Float
	{
		forEach(function(track) track.time = value);
		return value;
	}

	function get_playing():Bool
	{
		var result:Bool = false;
		forEach(function(track) if (track.playing) result = true);
		return result;
	}

	function set_volume(value:Float):Float
	{
		volume = value;
		for (track in player) if (track != null) applyVolume(track, playerVolume);
		for (track in opponent) if (track != null) applyVolume(track, opponentVolume);
		return volume;
	}

	function set_playerVolume(value:Float):Float
	{
		playerVolume = value;
		for (track in player) if (track != null) applyVolume(track, playerVolume);
		return playerVolume;
	}

	function set_opponentVolume(value:Float):Float
	{
		opponentVolume = value;
		for (track in opponent) if (track != null) applyVolume(track, opponentVolume);
		return opponentVolume;
	}

	function set_pitch(value:Float):Float
	{
		pitch = value;
		forEach(function(track) track.pitch = value);
		return pitch;
	}
}
