package funkin.audio.miniaudio;

import haxe.io.Bytes;

#if cpp
@:build(funkin.util.macro.NativeLibrary.build('miniaudio'))
#end
class MiniAudio
{
	public static var available(get, never):Bool;
	public static var ready(get, never):Bool;
	public static var version(get, never):String;
	public static var masterVolume(get, set):Float;

	public static function init():Bool
	{
		#if cpp
		return MiniAudioNative.engineInit();
		#else
		return false;
		#end
	}

	public static function shutdown():Void
	{
		#if cpp
		MiniAudioNative.engineShutdown();
		#end
	}

	public static function sampleRate():Int
	{
		#if cpp
		return MiniAudioNative.engineSampleRate();
		#else
		return 0;
		#end
	}

	public static function channels():Int
	{
		#if cpp
		return MiniAudioNative.engineChannels();
		#else
		return 0;
		#end
	}

	public static function bufferPeak(bytes:Bytes, offset:Int, length:Int, bitsPerSample:Int, channels:Int, startFrame:Int, frameCount:Int, channel:Int = -1):Float
	{
		if (bytes == null || length <= 0 || channels <= 0 || frameCount <= 0) return 0;
		if (offset < 0 || offset + length > bytes.length) return 0;
		#if cpp
		var pointer = cpp.Pointer.arrayElem(bytes.getData(), offset).constRaw;
		return MiniAudioNative.bufferPeak(pointer, length, bitsPerSample, channels, startFrame, frameCount, channel);
		#else
		return softwarePeak(bytes, offset, length, bitsPerSample, channels, startFrame, frameCount, channel);
		#end
	}

	public static function softwarePeak(bytes:Bytes, offset:Int, length:Int, bitsPerSample:Int, channels:Int, startFrame:Int, frameCount:Int, channel:Int = -1):Float
	{
		var bytesPerSample:Int = Std.int(bitsPerSample / 8);
		if (bytesPerSample <= 0) return 0;
		var totalFrames:Int = Std.int(length / (bytesPerSample * channels));
		var start:Int = startFrame < 0 ? 0 : startFrame;
		var end:Int = start + frameCount > totalFrames ? totalFrames : start + frameCount;
		var step:Int = Std.int(Math.max(1, (end - start) / 256));
		var peak:Float = 0;
		var frame:Int = start;
		while (frame < end)
		{
			for (c in 0...channels)
			{
				if (channel >= 0 && c != channel) continue;
				var position:Int = offset + (frame * channels + c) * bytesPerSample;
				var value:Float = switch (bytesPerSample)
				{
					case 1: (bytes.get(position) - 128) / 128;
					case 2:
						var raw:Int = bytes.getUInt16(position);
						(raw > 32767 ? raw - 65536 : raw) / 32768;
					case 4: bytes.getFloat(position);
					default: 0;
				}
				if (value < 0) value = -value;
				if (value > peak) peak = value;
			}
			frame += step;
		}
		return peak > 1 ? 1 : peak;
	}

	static function get_available():Bool
	{
		#if cpp
		return true;
		#else
		return false;
		#end
	}

	static function get_ready():Bool
	{
		#if cpp
		return MiniAudioNative.engineReady();
		#else
		return false;
		#end
	}

	static function get_version():String
	{
		#if cpp
		return MiniAudioNative.version().toString();
		#else
		return 'unavailable';
		#end
	}

	static function get_masterVolume():Float
	{
		#if cpp
		return MiniAudioNative.getMasterVolume();
		#else
		return 0;
		#end
	}

	static function set_masterVolume(value:Float):Float
	{
		#if cpp
		MiniAudioNative.setMasterVolume(value);
		#end
		return value;
	}
}
