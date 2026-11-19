package funkin.audio.miniaudio;

import haxe.io.Bytes;

class MiniAudioSound
{
	public var id(default, null):Int = -1;
	public var valid(get, never):Bool;
	public var playing(get, never):Bool;
	public var volume(get, set):Float;
	public var pan(default, set):Float = 0;
	public var pitch(default, set):Float = 1;
	public var looping(get, set):Bool;
	public var time(get, set):Float;
	public var length(get, never):Float;
	public var peak(get, never):Float;
	public var finished(get, never):Bool;

	function new(id:Int)
	{
		this.id = id;
	}

	public static function fromFile(path:String, stream:Bool = false):MiniAudioSound
	{
		#if cpp
		var id:Int = MiniAudioNative.soundLoadFile(cpp.ConstCharStar.fromString(path), stream);
		return id < 0 ? null : new MiniAudioSound(id);
		#else
		return null;
		#end
	}

	public static function fromBytes(bytes:Bytes):MiniAudioSound
	{
		#if cpp
		if (bytes == null || bytes.length < 1) return null;
		var id:Int = MiniAudioNative.soundLoadMemory(cpp.Pointer.arrayElem(bytes.getData(), 0).constRaw, bytes.length);
		return id < 0 ? null : new MiniAudioSound(id);
		#else
		return null;
		#end
	}

	public static function fromAsset(key:String):MiniAudioSound
	{
		#if sys
		if (sys.FileSystem.exists(key)) return fromBytes(sys.io.File.getBytes(key));
		#end
		if (openfl.utils.Assets.exists(key)) return fromBytes(openfl.utils.Assets.getBytes(key));
		return null;
	}

	public function play():MiniAudioSound
	{
		#if cpp
		if (valid) MiniAudioNative.soundPlay(id);
		#end
		return this;
	}

	public function stop():MiniAudioSound
	{
		#if cpp
		if (valid) MiniAudioNative.soundStop(id);
		#end
		return this;
	}

	public function destroy():Void
	{
		#if cpp
		if (valid) MiniAudioNative.soundRelease(id);
		#end
		id = -1;
	}

	inline function get_valid():Bool
		return id > -1;

	function get_playing():Bool
	{
		#if cpp
		return valid && MiniAudioNative.soundIsPlaying(id);
		#else
		return false;
		#end
	}

	function get_volume():Float
	{
		#if cpp
		return valid ? MiniAudioNative.soundGetVolume(id) : 0;
		#else
		return 0;
		#end
	}

	function set_volume(value:Float):Float
	{
		#if cpp
		if (valid) MiniAudioNative.soundSetVolume(id, value);
		#end
		return value;
	}

	function set_pan(value:Float):Float
	{
		#if cpp
		if (valid) MiniAudioNative.soundSetPan(id, value);
		#end
		return pan = value;
	}

	function set_pitch(value:Float):Float
	{
		#if cpp
		if (valid) MiniAudioNative.soundSetPitch(id, value);
		#end
		return pitch = value;
	}

	function get_looping():Bool
	{
		#if cpp
		return valid && MiniAudioNative.soundIsLooping(id);
		#else
		return false;
		#end
	}

	function set_looping(value:Bool):Bool
	{
		#if cpp
		if (valid) MiniAudioNative.soundSetLooping(id, value);
		#end
		return value;
	}

	function get_time():Float
	{
		#if cpp
		return valid ? MiniAudioNative.soundGetTime(id) : 0;
		#else
		return 0;
		#end
	}

	function set_time(value:Float):Float
	{
		#if cpp
		if (valid) MiniAudioNative.soundSeek(id, value);
		#end
		return value;
	}

	function get_length():Float
	{
		#if cpp
		return valid ? MiniAudioNative.soundGetLength(id) : 0;
		#else
		return 0;
		#end
	}

	function get_peak():Float
	{
		#if cpp
		return valid ? MiniAudioNative.soundGetPeak(id) : 0;
		#else
		return 0;
		#end
	}

	function get_finished():Bool
	{
		#if cpp
		return !valid || MiniAudioNative.soundAtEnd(id);
		#else
		return true;
		#end
	}
}
