package funkin.optimize;

enum abstract ThermalStatus(Int) from Int to Int
{
	var UNKNOWN = -1;
	var NONE = 0;
	var LIGHT = 1;
	var MODERATE = 2;
	var SEVERE = 3;
	var CRITICAL = 4;
	var EMERGENCY = 5;
	var SHUTDOWN = 6;
}

#if cpp
@:build(funkin.util.macro.NativeLibrary.build('optimize'))
#end
class Optimizer
{
	public static inline var FEATURE_TIMER:Int = 1;
	public static inline var FEATURE_PRIORITY:Int = 2;
	public static inline var FEATURE_POWER:Int = 4;
	public static inline var FEATURE_AFFINITY:Int = 8;
	public static inline var FEATURE_HINTS:Int = 16;
	public static inline var FEATURE_THERMAL:Int = 32;

	static inline var MB:Float = 1024 * 1024;
	static inline var THERMAL_POLL:Float = 5;

	public static var enabled(default, null):Bool = false;
	public static var features(default, null):Int = 0;
	public static var thermal(default, null):ThermalStatus = UNKNOWN;
	public static var onThermalChange(default, null):flixel.util.FlxSignal.FlxTypedSignal<ThermalStatus->Void> = new flixel.util.FlxSignal.FlxTypedSignal<ThermalStatus->Void>();

	static var hooked:Bool = false;
	static var thermalTimer:Float = 0;
	static var lastTarget:Float = 0;

	public static function init()
	{
		#if cpp
		if (enabled) return;
		if (!Save.data.nativeOptimizations)
		{
			tuneGC(false);
			return;
		}
		enabled = true;
		features = OptimizeNative.init(Save.data.pinBigCores ? 1 : 0);
		tuneGC(true);
		hook();
		syncTarget();
		thermal = readThermal();
		#end
	}

	public static function shutdown()
	{
		#if cpp
		if (!enabled) return;
		enabled = false;
		OptimizeNative.shutdown();
		features = 0;
		lastTarget = 0;
		#end
	}

	public static function refresh()
	{
		shutdown();
		init();
	}

	public static inline function has(feature:Int):Bool
		return features & feature != 0;

	static function hook()
	{
		if (hooked || FlxG.signals == null) return;
		hooked = true;
		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postDraw.add(onPostDraw);
		FlxG.signals.preStateSwitch.add(onStateSwitch);
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		FlxG.signals.focusLost.add(onFocusLost);
	}

	static function tuneGC(aggressive:Bool)
	{
		#if cpp
		var mobile:Bool = #if mobile true #else false #end;
		var working:Float = (aggressive ? (mobile ? 64 : 160) : (mobile ? 32 : 64)) * MB;
		var total:Float = totalMemory();
		if (total > 0 && working > total / 16) working = total / 16;
		cpp.vm.Gc.setMinimumWorkingMemory(Std.int(working));
		cpp.vm.Gc.setTargetFreeSpacePercentage(aggressive ? 40 : 25);
		#end
	}

	static function onPreUpdate()
	{
		#if cpp
		if (!enabled) return;
		OptimizeNative.frameBegin();
		thermalTimer += FlxG.elapsed;
		if (thermalTimer >= THERMAL_POLL && (#if ios true #else has(FEATURE_THERMAL) #end))
		{
			thermalTimer = 0;
			var status:ThermalStatus = readThermal();
			if (status != thermal)
			{
				thermal = status;
				onThermalChange.dispatch(status);
			}
		}
		#end
	}

	static function onPostDraw()
	{
		#if cpp
		if (!enabled) return;
		OptimizeNative.frameEnd();
		syncTarget();
		#end
	}

	static function syncTarget()
	{
		#if cpp
		var target:Float = Math.min(FlxG.drawFramerate, Math.max(30, funkin.util.FPSManager.displayRate()));
		if (target == lastTarget) return;
		lastTarget = target;
		OptimizeNative.setTargetFps(target);
		#end
	}

	static function onStateSwitch()
	{
		#if cpp
		if (!enabled) return;
		OptimizeNative.reset();
		#end
	}

	static function onPostStateSwitch()
	{
		#if cpp
		if (!enabled) return;
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		OptimizeNative.trimMemory();
		#end
	}

	static function onFocusLost()
	{
		#if cpp
		if (!enabled) return;
		OptimizeNative.trimMemory();
		#end
	}

	public static function trimMemory():Bool
	{
		#if cpp
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		return OptimizeNative.trimMemory() != 0;
		#else
		return false;
		#end
	}

	public static function now():Float
	{
		#if cpp
		return OptimizeNative.now();
		#else
		return haxe.Timer.stamp();
		#end
	}

	public static function preciseSleep(seconds:Float)
	{
		#if cpp
		OptimizeNative.sleep(seconds);
		#else
		Sys.sleep(seconds);
		#end
	}

	public static function cpuCount():Int
	{
		#if cpp
		return OptimizeNative.cpuCount();
		#else
		return 1;
		#end
	}

	public static function bigCoreCount():Int
	{
		#if cpp
		return OptimizeNative.bigCoreCount();
		#else
		return 1;
		#end
	}

	public static function totalMemory():Float
	{
		#if cpp
		return toFloat(OptimizeNative.totalMemory());
		#else
		return -1;
		#end
	}

	public static function availableMemory():Float
	{
		#if cpp
		return toFloat(OptimizeNative.availableMemory());
		#else
		return -1;
		#end
	}

	public static function processMemory():Float
	{
		#if cpp
		return toFloat(OptimizeNative.processMemory());
		#else
		return -1;
		#end
	}

	#if cpp
	static inline function toFloat(value:cpp.Int64):Float
		return untyped __cpp__('(double){0}', value);
	#end

	public static function averageFps():Float
	{
		#if cpp
		return enabled ? OptimizeNative.averageFps() : 0;
		#else
		return 0;
		#end
	}

	public static function lowFps():Float
	{
		#if cpp
		return enabled ? OptimizeNative.lowFps() : 0;
		#else
		return 0;
		#end
	}

	public static function frameTimeMs():Float
	{
		#if cpp
		return enabled ? OptimizeNative.averageFrameMs() : 0;
		#else
		return 0;
		#end
	}

	public static function workTimeMs():Float
	{
		#if cpp
		return enabled ? OptimizeNative.averageWorkMs() : 0;
		#else
		return 0;
		#end
	}

	public static function jitterMs():Float
	{
		#if cpp
		return enabled ? OptimizeNative.jitterMs() : 0;
		#else
		return 0;
		#end
	}

	public static function performanceHintActive():Bool
	{
		#if cpp
		return enabled && OptimizeNative.hintActive() != 0;
		#else
		return false;
		#end
	}

	static function readThermal():ThermalStatus
	{
		#if ios
		return (lime.system.MobilePerformance.thermalStatus : Int);
		#elseif cpp
		return OptimizeNative.thermalStatus();
		#else
		return UNKNOWN;
		#end
	}

	public static function thermalName():String
	{
		return switch (thermal)
		{
			case NONE: 'Normal';
			case LIGHT: 'Light';
			case MODERATE: 'Moderate';
			case SEVERE: 'Severe';
			case CRITICAL: 'Critical';
			case EMERGENCY: 'Emergency';
			case SHUTDOWN: 'Shutdown';
			default: 'Unknown';
		}
	}
}
