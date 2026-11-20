package funkin.audio.miniaudio;

#if cpp
@:include('funkin_miniaudio.h')
extern class MiniAudioNative
{
	@:native('::funkin_miniaudio::engineInit') static function engineInit():Bool;
	@:native('::funkin_miniaudio::engineInitEx') static function engineInitEx(sampleRate:Int, periodMilliseconds:Int, lowLatency:Bool):Bool;
	@:native('::funkin_miniaudio::engineShutdown') static function engineShutdown():Void;
	@:native('::funkin_miniaudio::engineReady') static function engineReady():Bool;
	@:native('::funkin_miniaudio::engineSuspend') static function engineSuspend():Bool;
	@:native('::funkin_miniaudio::engineResume') static function engineResume():Bool;
	@:native('::funkin_miniaudio::engineSuspended') static function engineSuspended():Bool;
	@:native('::funkin_miniaudio::engineUpdate') static function engineUpdate():Void;
	@:native('::funkin_miniaudio::setMasterVolume') static function setMasterVolume(volume:cpp.Float32):Void;
	@:native('::funkin_miniaudio::getMasterVolume') static function getMasterVolume():cpp.Float32;
	@:native('::funkin_miniaudio::engineSampleRate') static function engineSampleRate():Int;
	@:native('::funkin_miniaudio::engineChannels') static function engineChannels():Int;
	@:native('::funkin_miniaudio::engineTime') static function engineTime():Float;
	@:native('::funkin_miniaudio::engineLatency') static function engineLatency():cpp.Float32;
	@:native('::funkin_miniaudio::enginePeak') static function enginePeak():cpp.Float32;
	@:native('::funkin_miniaudio::groupCreate') static function groupCreate(parent:Int):Int;
	@:native('::funkin_miniaudio::groupRelease') static function groupRelease(id:Int):Void;
	@:native('::funkin_miniaudio::groupSetVolume') static function groupSetVolume(id:Int, volume:cpp.Float32):Void;
	@:native('::funkin_miniaudio::groupGetVolume') static function groupGetVolume(id:Int):cpp.Float32;
	@:native('::funkin_miniaudio::groupSetPitch') static function groupSetPitch(id:Int, pitch:cpp.Float32):Void;
	@:native('::funkin_miniaudio::groupSetPan') static function groupSetPan(id:Int, pan:cpp.Float32):Void;
	@:native('::funkin_miniaudio::groupStart') static function groupStart(id:Int):Bool;
	@:native('::funkin_miniaudio::groupStop') static function groupStop(id:Int):Bool;
	@:native('::funkin_miniaudio::soundLoadFileEx') static function soundLoadFileEx(path:cpp.ConstCharStar, stream:Bool, group:Int):Int;
	@:native('::funkin_miniaudio::soundLoadMemoryEx') static function soundLoadMemoryEx(data:cpp.RawConstPointer<cpp.UInt8>, size:Int, group:Int):Int;
	@:native('::funkin_miniaudio::soundClone') static function soundClone(id:Int, group:Int):Int;
	@:native('::funkin_miniaudio::soundRelease') static function soundRelease(id:Int):Void;
	@:native('::funkin_miniaudio::soundCount') static function soundCount():Int;
	@:native('::funkin_miniaudio::soundPlay') static function soundPlay(id:Int):Bool;
	@:native('::funkin_miniaudio::soundPlayDelayed') static function soundPlayDelayed(id:Int, delayMilliseconds:Float):Bool;
	@:native('::funkin_miniaudio::soundStop') static function soundStop(id:Int):Bool;
	@:native('::funkin_miniaudio::soundStopFade') static function soundStopFade(id:Int, milliseconds:Float):Bool;
	@:native('::funkin_miniaudio::soundIsPlaying') static function soundIsPlaying(id:Int):Bool;
	@:native('::funkin_miniaudio::soundFade') static function soundFade(id:Int, from:cpp.Float32, to:cpp.Float32, milliseconds:Float):Void;
	@:native('::funkin_miniaudio::soundSetVolume') static function soundSetVolume(id:Int, volume:cpp.Float32):Void;
	@:native('::funkin_miniaudio::soundGetVolume') static function soundGetVolume(id:Int):cpp.Float32;
	@:native('::funkin_miniaudio::soundSetPan') static function soundSetPan(id:Int, pan:cpp.Float32):Void;
	@:native('::funkin_miniaudio::soundSetPitch') static function soundSetPitch(id:Int, pitch:cpp.Float32):Void;
	@:native('::funkin_miniaudio::soundSetLooping') static function soundSetLooping(id:Int, looping:Bool):Void;
	@:native('::funkin_miniaudio::soundIsLooping') static function soundIsLooping(id:Int):Bool;
	@:native('::funkin_miniaudio::soundAtEnd') static function soundAtEnd(id:Int):Bool;
	@:native('::funkin_miniaudio::soundSeek') static function soundSeek(id:Int, milliseconds:Float):Void;
	@:native('::funkin_miniaudio::soundGetTime') static function soundGetTime(id:Int):Float;
	@:native('::funkin_miniaudio::soundGetLength') static function soundGetLength(id:Int):Float;
	@:native('::funkin_miniaudio::soundGetPeak') static function soundGetPeak(id:Int):cpp.Float32;
	@:native('::funkin_miniaudio::soundGetRms') static function soundGetRms(id:Int):cpp.Float32;
	@:native('::funkin_miniaudio::soundSampleRate') static function soundSampleRate(id:Int):Int;
	@:native('::funkin_miniaudio::soundChannels') static function soundChannels(id:Int):Int;
	@:native('::funkin_miniaudio::bufferPeak') static function bufferPeak(data:cpp.RawConstPointer<cpp.UInt8>, byteLength:Int, bitsPerSample:Int, channels:Int, startFrame:Int, frameCount:Int, channel:Int):cpp.Float32;
}
#end
