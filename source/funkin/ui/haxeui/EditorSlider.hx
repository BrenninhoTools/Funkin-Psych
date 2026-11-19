package funkin.ui.haxeui;

import haxe.ui.components.HorizontalSlider;
import haxe.ui.events.UIEvent;

class EditorSlider extends EditorWidget<HorizontalSlider>
{
	public static final CHANGE_EVENT:String = funkin.ui.psych.PsychUISlider.CHANGE_EVENT;

	public var onChange:Float->Void;
	public var value(get, set):Float;
	public var min(get, set):Float;
	public var max(get, set):Float;
	public var decimals(get, set):Int;
	public var label(get, set):String;
	public var labelText(default, null):FlxText;
	public var valueText(default, null):FlxText;

	public function new(x:Float = 0, y:Float = 0, callback:Float->Void, def:Float = 0, min:Float = -999, max:Float = 999, wid:Float = 200, ?mainColor:FlxColor, ?handleColor:FlxColor)
	{
		EditorUI.ensureToolkit();
		var slider:HorizontalSlider = new HorizontalSlider();
		slider.width = wid;
		slider.min = min;
		slider.max = max;
		slider.precision = 2;
		super(x, y, slider);
		onChange = callback;

		labelText = new FlxText(0, -14, wid, '', 8);
		labelText.alignment = CENTER;
		add(labelText);
		valueText = new FlxText(0, 18, wid, '', 8);
		valueText.alignment = CENTER;
		add(valueText);

		value = def;
		slider.registerEvent(UIEvent.CHANGE, function(_)
		{
			updateValueText();
			if (silent) return;
			if (onChange != null) onChange(value);
			broadcast(CHANGE_EVENT);
		});
	}

	function updateValueText()
		valueText.text = Std.string(value);

	function get_value():Float
		return component.pos;

	function set_value(v:Float):Float
	{
		v = Math.max(min, Math.min(max, v));
		quietly(() -> component.pos = v);
		updateValueText();
		return v;
	}

	function get_min():Float
		return component.min;

	function set_min(v:Float):Float
	{
		component.min = v;
		return v;
	}

	function get_max():Float
		return component.max;

	function set_max(v:Float):Float
	{
		component.max = v;
		return v;
	}

	function get_decimals():Int
		return component.precision != null ? component.precision : 2;

	function set_decimals(v:Int):Int
	{
		component.precision = v;
		return v;
	}

	function get_label():String
		return labelText.text;

	function set_label(v:String):String
	{
		labelText.text = v;
		return v;
	}
}
