package funkin.util.math;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;

class MathUtil
{
	public static inline final EPSILON:Float = 0.0000001;
	public static inline final TAU:Float = 6.283185307179586;
	public static inline final DEG_TO_RAD:Float = 0.017453292519943295;
	public static inline final RAD_TO_DEG:Float = 57.29577951308232;

	public static inline function clamp(value:Float, min:Float, max:Float):Float
		return value < min ? min : (value > max ? max : value);

	public static inline function clampInt(value:Int, min:Int, max:Int):Int
		return value < min ? min : (value > max ? max : value);

	public static inline function lerp(from:Float, to:Float, ratio:Float):Float
		return from + (to - from) * ratio;

	public static inline function inverseLerp(from:Float, to:Float, value:Float):Float
		return Math.abs(to - from) < EPSILON ? 0 : (value - from) / (to - from);

	public static inline function remap(value:Float, fromMin:Float, fromMax:Float, toMin:Float, toMax:Float):Float
		return lerp(toMin, toMax, inverseLerp(fromMin, fromMax, value));

	public static inline function smoothLerp(current:Float, target:Float, elapsed:Float, speed:Float):Float
		return FlxMath.lerp(target, current, Math.exp(-elapsed * speed));

	public static inline function smoothLerpPrecision(current:Float, target:Float, elapsed:Float, duration:Float, precision:Float = 1 / 100):Float
		return duration <= 0 ? target : FlxMath.lerp(target, current, Math.pow(precision, elapsed / duration));

	public static inline function frameRatio(elapsed:Float, ratio:Float, fps:Float = 60):Float
		return 1 - Math.pow(1 - ratio, elapsed * fps);

	public static inline function approach(value:Float, target:Float, step:Float):Float
		return value < target ? Math.min(value + step, target) : Math.max(value - step, target);

	public static function wrap(value:Float, min:Float, max:Float):Float
	{
		var range:Float = max - min;
		if (range == 0) return min;
		var result:Float = (value - min) % range;
		if (result < 0) result += range;
		return result + min;
	}

	public static function wrapInt(value:Int, min:Int, max:Int):Int
	{
		var range:Int = max - min + 1;
		if (range <= 0) return min;
		var result:Int = (value - min) % range;
		if (result < 0) result += range;
		return result + min;
	}

	public static inline function snap(value:Float, step:Float):Float
		return step == 0 ? value : Math.fround(value / step) * step;

	public static inline function quantize(value:Float, snap:Float):Float
		return Math.fround(value * snap) / snap;

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);
		var factor:Float = Math.pow(10, decimals);
		return Math.floor(value * factor) / factor;
	}

	public static function roundDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.fround(value);
		var factor:Float = Math.pow(10, decimals);
		return Math.fround(value * factor) / factor;
	}

	public static inline function sign(value:Float):Int
		return value > 0 ? 1 : (value < 0 ? -1 : 0);

	public static inline function equals(a:Float, b:Float, tolerance:Float = EPSILON):Bool
		return Math.abs(a - b) <= tolerance;

	public static inline function isZero(value:Float, tolerance:Float = EPSILON):Bool
		return Math.abs(value) <= tolerance;

	public static inline function toRadians(degrees:Float):Float
		return degrees * DEG_TO_RAD;

	public static inline function toDegrees(radians:Float):Float
		return radians * RAD_TO_DEG;

	public static function angleDifference(from:Float, to:Float):Float
		return wrap(to - from + 180, 0, 360) - 180;

	public static inline function lerpAngle(from:Float, to:Float, ratio:Float):Float
		return from + angleDifference(from, to) * ratio;

	public static inline function distance(x1:Float, y1:Float, x2:Float, y2:Float):Float
		return Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));

	public static inline function angleBetween(x1:Float, y1:Float, x2:Float, y2:Float):Float
		return Math.atan2(y2 - y1, x2 - x1) * RAD_TO_DEG;

	public static function pointOnCircle(centerX:Float, centerY:Float, radius:Float, degrees:Float, ?result:FlxPoint):FlxPoint
	{
		if (result == null) result = FlxPoint.get();
		var radians:Float = degrees * DEG_TO_RAD;
		return result.set(centerX + Math.cos(radians) * radius, centerY + Math.sin(radians) * radius);
	}

	public static function numberArray(max:Int, ?min:Int = 0):Array<Int>
		return [for (i in min...max) i];

	public static function average(values:Array<Float>):Float
	{
		if (values == null || values.length == 0) return 0;
		var total:Float = 0;
		for (value in values) total += value;
		return total / values.length;
	}

	public static function median(values:Array<Float>):Float
	{
		if (values == null || values.length == 0) return 0;
		var sorted:Array<Float> = values.copy();
		sorted.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		var middle:Int = sorted.length >> 1;
		return sorted.length % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
	}

	public static inline function percent(value:Float, total:Float):Float
		return total == 0 ? 0 : value / total * 100;

	public static function gcd(a:Int, b:Int):Int
	{
		a = Std.int(Math.abs(a));
		b = Std.int(Math.abs(b));
		while (b != 0)
		{
			var next:Int = a % b;
			a = b;
			b = next;
		}
		return a;
	}

	public static inline function isPowerOfTwo(value:Int):Bool
		return value > 0 && (value & (value - 1)) == 0;

	public static function nextPowerOfTwo(value:Int):Int
	{
		var result:Int = 1;
		while (result < value) result <<= 1;
		return result;
	}

	public static inline function bezier(p0:Float, p1:Float, p2:Float, t:Float):Float
		return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;

	public static inline function cubicBezier(p0:Float, p1:Float, p2:Float, p3:Float, t:Float):Float
	{
		var u:Float = 1 - t;
		return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
	}

	public static inline function smoothStep(edge0:Float, edge1:Float, value:Float):Float
	{
		var t:Float = clamp((value - edge0) / (edge1 - edge0), 0, 1);
		return t * t * (3 - 2 * t);
	}

	public static inline function pingPong(value:Float, length:Float):Float
		return length - Math.abs(wrap(value, 0, length * 2) - length);
}
