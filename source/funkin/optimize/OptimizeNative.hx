package funkin.optimize;

#if cpp
@:include('funkin_optimize.h')
extern class OptimizeNative
{
	@:native('fo_init') static function init(pinBigCores:Int):Int;
	@:native('fo_shutdown') static function shutdown():Void;
	@:native('fo_features') static function features():Int;
	@:native('fo_platform') static function platform():cpp.ConstCharStar;
	@:native('fo_now') static function now():Float;
	@:native('fo_sleep') static function sleep(seconds:Float):Void;
	@:native('fo_cpu_count') static function cpuCount():Int;
	@:native('fo_big_core_count') static function bigCoreCount():Int;
	@:native('fo_pin_big_cores') static function pinBigCores():Int;
	@:native('fo_unpin_cores') static function unpinCores():Void;
	@:native('fo_total_memory') static function totalMemory():cpp.Int64;
	@:native('fo_available_memory') static function availableMemory():cpp.Int64;
	@:native('fo_process_memory') static function processMemory():cpp.Int64;
	@:native('fo_trim_memory') static function trimMemory():Int;
	@:native('fo_thermal_status') static function thermalStatus():Int;
	@:native('fo_hint_active') static function hintActive():Int;
	@:native('fo_hint_close') static function hintClose():Void;
	@:native('::funkin_optimize::frameBegin') static function frameBegin():Void;
	@:native('::funkin_optimize::frameEnd') static function frameEnd():Void;
	@:native('::funkin_optimize::setTargetFps') static function setTargetFps(fps:Float):Void;
	@:native('::funkin_optimize::reset') static function reset():Void;
	@:native('::funkin_optimize::averageFps') static function averageFps():Float;
	@:native('::funkin_optimize::lowFps') static function lowFps():Float;
	@:native('::funkin_optimize::averageFrameMs') static function averageFrameMs():Float;
	@:native('::funkin_optimize::averageWorkMs') static function averageWorkMs():Float;
	@:native('::funkin_optimize::jitterMs') static function jitterMs():Float;
	@:native('::funkin_optimize::samples') static function samples():Int;
}
#end
