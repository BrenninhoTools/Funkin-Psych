package funkin.audio.miniaudio;

#if cpp
@:include('funkin_miniaudio.h')
extern class MiniAudioNative
{
	@:native('::funkin_miniaudio::version') static function version():cpp.ConstCharStar;
	@:native('::funkin_miniaudio::engineInit') static function engineInit():Bool;
	@:native('::funkin_miniaudio::engineShutdown') static function engineShutdown():Void;
	@:native('::funkin_miniaudio::engineReady') static function engineReady():Bool;
	@:native('::funkin_miniaudio::setMasterVolume') static function setMasterVolume(volume:cpp.Float32):Void;
	@:native('::funkin_miniaudio::getMasterVolume') static function getMasterVolume():cpp.Float32;
	@:native('::funkin_miniaudio::engineSampleRate') static function engineSampleRate():Int;
	@:native('::funkin_miniaudio::engineChannels') static function engineChannels():Int;
	@:native('::funkin_miniaudio::soundLoadFile') static function soundLoadFile(path:cpp.ConstCharStar, stream:Bool):Int;
	@:native('::funkin_miniaudio::soundLoadMemory') static function soundLoadMemory(data:cpp.RawConstPointer<cpp.UInt8>, size:Int):Int;
	@:native('::funkin_miniaudio::soundRelease') static function soundRelease(id:Int):Void;
	@:native('::funkin_miniaudio::soundPlay') static function soundPlay(id:Int):Bool;
	@:native('::funkin_miniaudio::soundStop') static function soundStop(id:Int):Bool;
	@:native('::funkin_miniaudio::soundIsPlaying') static function soundIsPlaying(id:Int):Bool;
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
	@:native('::funkin_miniaudio::bufferPeak') static function bufferPeak(data:cpp.RawConstPointer<cpp.UInt8>, byteLength:Int, bitsPerSample:Int, channels:Int, startFrame:Int, frameCount:Int, channel:Int):cpp.Float32;
}
#end
