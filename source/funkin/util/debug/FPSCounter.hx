package funkin.util.debug;

import flixel.FlxG;
import flixel.util.FlxStringUtil;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class FPSCounter extends Sprite
{
	public static inline final SEPARATOR:String = '  •  ';

	public var currentFPS(default, null):Int = 0;
	public var memoryMegas(get, never):Float;
	public var memoryPeak(default, null):Float = 0;
	public var textColor(get, set):Int;
	public var text(get, set):String;
	public var padding:Float = 6;
	public var barAlpha(default, set):Float = 0.6;

	public var label(default, null):TextField;
	public var bar(default, null):Shape;

	var times:Array<Float> = [];
	var lastRefresh:Float = 0;
	var systemName:String;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();
		this.x = x;
		this.y = y;
		mouseEnabled = mouseChildren = false;

		bar = new Shape();
		addChild(bar);

		label = new TextField();
		label.selectable = false;
		label.mouseEnabled = false;
		label.defaultTextFormat = new TextFormat("_sans", 14, color);
		label.autoSize = TextFieldAutoSize.LEFT;
		label.multiline = false;
		label.x = padding;
		label.y = padding * 0.5;
		label.text = 'FPS: 0';
		addChild(label);

		systemName = describeSystem();
		addEventListener(openfl.events.Event.ENTER_FRAME, onEnterFrame);
	}

	function onEnterFrame(_)
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		if (now - lastRefresh < 50) return;
		lastRefresh = now;

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		var memory:Float = memoryMegas;
		if (memory > memoryPeak) memoryPeak = memory;
		updateText();
		redrawBar();
	}

	public dynamic function updateText():Void
	{
		var rework:String = funkin.util.FPSManager.describe();
		var fps:String = 'FPS: $currentFPS' + (rework.length > 0 ? ' ($rework)' : '');
		var memory:String = 'Memory: ${FlxStringUtil.formatBytes(memoryMegas)} / ${FlxStringUtil.formatBytes(memoryPeak)}';
		label.text = [fps, memory, 'Task: ${describeTask()}', 'System: $systemName'].join(SEPARATOR);
		label.textColor = currentFPS < funkin.util.FPSManager.warningFPS() ? 0xFFFF4040 : 0xFFFFFFFF;
	}

	public function redrawBar()
	{
		label.x = padding;
		label.y = padding * 0.5;
		bar.graphics.clear();
		bar.graphics.beginFill(0x000000, barAlpha);
		bar.graphics.drawRect(0, 0, label.width + padding * 2, label.height + padding);
		bar.graphics.endFill();
	}

	public static function describeTask():String
	{
		var state:flixel.FlxState = FlxG.state;
		if (state == null) return 'Booting';
		var names:Array<String> = [className(state)];
		var sub:flixel.FlxState = state.subState;
		while (sub != null)
		{
			names.push(className(sub));
			sub = sub.subState;
		}
		return names.join(' > ');
	}

	static function className(object:Dynamic):String
	{
		var name:String = Type.getClassName(Type.getClass(object));
		if (name == null) return 'Unknown';
		var dot:Int = name.lastIndexOf('.');
		return dot > -1 ? name.substr(dot + 1) : name;
	}

	public static function describeSystem():String
	{
		var platform:String = lime.system.System.platformName;
		var version:String = lime.system.System.platformVersion;
		var label:String = lime.system.System.platformLabel;
		var result:String = '';
		if (platform != null && platform.length > 0)
		{
			result = platform;
			if (version != null && version.length > 0 && result.indexOf(version) < 0) result += ' $version';
		}
		else if (label != null) result = label;
		var model:String = lime.system.System.deviceModel;
		#if mobile
		if (model != null && model.length > 0) result += ' ($model)';
		#end
		return result.length > 0 ? result.trim() : 'Unknown';
	}

	function get_textColor():Int
		return label.textColor;

	function set_textColor(value:Int):Int
	{
		label.textColor = value;
		return value;
	}

	function get_text():String
		return label.text;

	function set_text(value:String):String
	{
		label.text = value;
		redrawBar();
		return value;
	}

	function set_barAlpha(value:Float):Float
	{
		barAlpha = value;
		if (bar != null) redrawBar();
		return value;
	}

	inline function get_memoryMegas():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#elseif hl
		return hl.Gc.stats().currentMemory;
		#else
		return openfl.system.System.totalMemory;
		#end
	}
}
