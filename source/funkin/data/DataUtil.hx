package funkin.data;

class DataUtil
{
	public static function parseJson(raw:String):Dynamic
	{
		if (raw == null || raw.trim().length == 0) return null;
		try
		{
			return tjson.TJSON.parse(raw);
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Invalid JSON: $e');
			return null;
		}
	}

	public static function vector(value:Dynamic, defaultX:Float = 0, defaultY:Float = 0):Array<Float>
	{
		if (value == null) return [defaultX, defaultY];
		if (Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = cast value;
			return [list.length > 0 ? toFloat(list[0], defaultX) : defaultX, list.length > 1 ? toFloat(list[1], defaultY) : defaultY];
		}
		if (Std.isOfType(value, Float) || Std.isOfType(value, Int))
		{
			var single:Float = toFloat(value, defaultX);
			return [single, single];
		}
		return [toFloat(Reflect.field(value, 'x'), defaultX), toFloat(Reflect.field(value, 'y'), defaultY)];
	}

	public static function intVector(value:Dynamic):Array<Int>
	{
		if (value == null) return null;
		var vec:Array<Float> = vector(value);
		return [Std.int(vec[0]), Std.int(vec[1])];
	}

	public static function toFloat(value:Dynamic, fallback:Float = 0):Float
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) return value;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	public static function toInt(value:Dynamic, fallback:Int = 0):Int
		return Std.int(toFloat(value, fallback));

	public static function toBool(value:Dynamic, fallback:Bool = false):Bool
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Bool)) return value;
		var text:String = Std.string(value).toLowerCase();
		return text == 'true' || text == '1';
	}

	public static function intArray(value:Dynamic):Array<Int>
	{
		if (value == null || !Std.isOfType(value, Array)) return [];
		return [for (entry in (cast value:Array<Dynamic>)) toInt(entry)];
	}

	public static function rgb(value:Dynamic, ?fallback:Array<Int>):Array<Int>
	{
		if (fallback == null) fallback = [161, 161, 161];
		if (value == null) return fallback;
		if (Std.isOfType(value, Array))
		{
			var list:Array<Int> = intArray(value);
			return list.length >= 3 ? [list[0], list[1], list[2]] : fallback;
		}
		var color:Null<FlxColor> = Std.isOfType(value, Int) ? (value:Int) : FlxColor.fromString(colorString(Std.string(value)));
		if (color == null) return fallback;
		var resolved:FlxColor = color;
		return [resolved.red, resolved.green, resolved.blue];
	}

	public static function colorString(value:String):String
	{
		if (value == null) return '#FFFFFF';
		var text:String = value.trim();
		if (text.startsWith('0x') || text.startsWith('#')) return text;
		return '#' + text;
	}

	public static function hex(rgbValues:Array<Int>):String
	{
		if (rgbValues == null || rgbValues.length < 3) return '#A1A1A1';
		return '#' + StringTools.hex(rgbValues[0], 2) + StringTools.hex(rgbValues[1], 2) + StringTools.hex(rgbValues[2], 2);
	}

	public static function stringify(data:Dynamic, ?inlineKeys:Array<String>):String
	{
		if (inlineKeys == null) inlineKeys = [];
		return funkin.ui.debug.content.PsychJsonPrinter.print(data, inlineKeys);
	}

	public static function field(data:Dynamic, names:Array<String>):Dynamic
	{
		if (data == null) return null;
		for (name in names)
		{
			var value:Dynamic = Reflect.field(data, name);
			if (value != null) return value;
		}
		return null;
	}
}
