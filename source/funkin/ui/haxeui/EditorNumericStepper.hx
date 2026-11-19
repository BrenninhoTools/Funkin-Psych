package funkin.ui.haxeui;

import haxe.ui.components.NumberStepper;
import haxe.ui.events.UIEvent;
import haxe.ui.events.FocusEvent;

class EditorNumericStepper extends EditorWidget<NumberStepper>
{
	public static final CHANGE_EVENT:String = funkin.ui.psych.PsychUINumericStepper.CHANGE_EVENT;

	public var onValueChange:Void->Void;
	public var unfocus:Void->Void;
	public var value(get, set):Float;
	public var step(get, set):Float;
	public var min(get, set):Float;
	public var max(get, set):Float;
	public var decimals(get, set):Int;
	public var isPercent:Bool = false;
	public var text(get, never):String;

	public function new(x:Float = 0, y:Float = 0, step:Float = 1, defValue:Float = 0, min:Float = -999, max:Float = 999, decimals:Int = 0, ?wid:Int = 60, ?isPercent:Bool = false)
	{
		var stepper:NumberStepper = new NumberStepper();
		stepper.width = wid + 32;
		stepper.height = 22;
		stepper.customStyle.fontSize = 11;
		stepper.min = min;
		stepper.max = max;
		stepper.step = step;
		stepper.precision = decimals;
		super(x, y, stepper);
		this.isPercent = isPercent;
		value = defValue;
		stepper.registerEvent(UIEvent.CHANGE, function(_)
		{
			if (silent) return;
			if (onValueChange != null) onValueChange();
			broadcast(CHANGE_EVENT);
		});
		stepper.registerEvent(FocusEvent.FOCUS_OUT, function(_) if (unfocus != null) unfocus());
	}

	function clampValue(v:Float):Float
	{
		if (Math.isNaN(v)) v = 0;
		v = Math.max(component.min != null ? component.min : v, Math.min(component.max != null ? component.max : v, v));
		var factor:Float = Math.pow(10, decimals);
		return Math.round(v * factor) / factor;
	}

	function get_value():Float
	{
		var pos:Null<Float> = component.pos;
		return pos != null ? pos : 0;
	}

	function set_value(v:Float):Float
	{
		v = clampValue(v);
		quietly(() -> component.pos = v);
		return v;
	}

	function get_step():Float
		return component.step != null ? component.step : 1;

	function set_step(v:Float):Float
	{
		component.step = v;
		return v;
	}

	function get_min():Float
		return component.min != null ? component.min : -999;

	function set_min(v:Float):Float
	{
		component.min = v;
		if (value < v) value = v;
		return v;
	}

	function get_max():Float
		return component.max != null ? component.max : 999;

	function set_max(v:Float):Float
	{
		component.max = v;
		if (value > v) value = v;
		return v;
	}

	function get_decimals():Int
		return component.precision != null ? component.precision : 0;

	function set_decimals(v:Int):Int
	{
		component.precision = v;
		return v;
	}

	function get_text():String
		return Std.string(value);
}
