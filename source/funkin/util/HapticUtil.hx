package funkin.util;

#if mobile
import extension.haptics.Haptic;
#end

enum abstract HapticsMode(Int) from Int to Int
{
	var NONE = 0;
	var NOTES_ONLY = 1;
	var ALL = 2;

	public static function fromString(value:String):HapticsMode
	{
		return switch (value)
		{
			case 'None': NONE;
			case 'Notes Only': NOTES_ONLY;
			default: ALL;
		}
	}
}

typedef VibrationPreset =
{
	var period:Float;
	var duration:Float;
	var amplitude:Float;
	var sharpness:Float;
}

class HapticUtil
{
	public static inline var DEFAULT_PERIOD:Float = 0.1;
	public static inline var DEFAULT_DURATION:Float = 0.1;
	public static inline var MIN_AMPLITUDE:Float = 0.25;
	public static inline var DEFAULT_AMPLITUDE:Float = 0.5;
	public static inline var MAX_AMPLITUDE:Float = 1;
	public static inline var DEFAULT_SHARPNESS:Float = 1;
	public static final MODES:Array<String> = ['All', 'Notes Only', 'None'];
	static final NOTE_MODES:Array<HapticsMode> = [ALL, NOTES_ONLY];

	public static var amplitudeTween:FlxTween;
	public static var mode(get, never):HapticsMode;
	public static var available(get, never):Bool;

	static var initialized:Bool = false;
	static var notesThisFrame:Int = 0;
	static var holdsThisFrame:Float = 0;
	static var missThisFrame:Bool = false;

	static function get_mode():HapticsMode
		return HapticsMode.fromString(Save.data.hapticsMode);

	static function get_available():Bool
	{
		#if mobile
		return mode != NONE && Save.data.hapticsIntensity > 0;
		#else
		return false;
		#end
	}

	#if mobile
	static function init()
	{
		if (initialized) return;
		initialized = true;
		try
		{
			Haptic.initialize();
		}
		catch (e:Dynamic) {}
	}
	#end

	public static function vibrate(period:Float = DEFAULT_PERIOD, duration:Float = DEFAULT_DURATION, amplitude:Float = DEFAULT_AMPLITUDE,
			sharpness:Float = DEFAULT_SHARPNESS, ?modes:Array<HapticsMode>):Void
	{
		#if mobile
		if (!available) return;
		if (!(modes != null ? modes : [ALL]).contains(mode)) return;
		init();
		var value:Float = FlxMath.bound(amplitude * Save.data.hapticsIntensity, 0, MAX_AMPLITUDE);
		if (value <= 0 || duration <= 0) return;
		try
		{
			if (period > 0)
			{
				var half:Float = period / 2;
				var count:Int = Math.ceil(duration / half);
				Haptic.vibratePattern([for (i in 0...count) half], [for (i in 0...count) value], [for (i in 0...count) sharpness]);
			}
			else Haptic.vibrateOneShot(duration, value, sharpness);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function vibrateByPreset(?preset:VibrationPreset):Void
	{
		if (preset == null) preset = {period: DEFAULT_PERIOD, duration: DEFAULT_DURATION, amplitude: DEFAULT_AMPLITUDE, sharpness: DEFAULT_SHARPNESS};
		vibrate(preset.period, preset.duration, preset.amplitude, preset.sharpness);
	}

	public static function increasingVibrate(startAmplitude:Float, targetAmplitude:Float, tweenDuration:Float = 1):Void
	{
		if (!available) return;
		if (amplitudeTween != null) amplitudeTween.cancel();
		amplitudeTween = FlxTween.num(startAmplitude, targetAmplitude, tweenDuration, {
			onComplete: function(_) vibrate(DEFAULT_PERIOD, DEFAULT_DURATION, targetAmplitude * 2)
		}, function(value:Float) vibrate(0, DEFAULT_DURATION / 10, value));
	}

	public static inline function menuScroll()
		vibrate(0, 0.01, 0.5);

	public static inline function menuConfirm()
		vibrate(0, 0.05, 1);

	public static inline function menuBack()
		vibrate(0, 0.01, 0.2);

	public static function noteHit()
		notesThisFrame++;

	public static function holdNote(ended:Bool = false)
		holdsThisFrame += MAX_AMPLITUDE / (ended ? 4 : 10);

	public static function noteMiss()
		missThisFrame = true;

	public static function flushNotes()
	{
		if (notesThisFrame > 0)
		{
			var amplitude:Float = Math.min(MAX_AMPLITUDE, notesThisFrame * MAX_AMPLITUDE / 4);
			vibrate(0, 0.01, amplitude * 2.5, 1, NOTE_MODES);
		}
		else if (holdsThisFrame > 0) vibrate(0, 0.01, Math.min(MAX_AMPLITUDE, holdsThisFrame) * 2.5, 1, NOTE_MODES);

		if (missThisFrame) vibrate(0, 0.06, MAX_AMPLITUDE, 0.4, NOTE_MODES);

		notesThisFrame = 0;
		holdsThisFrame = 0;
		missThisFrame = false;
	}
}
