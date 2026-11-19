package funkin.ui.haxeui;

import haxe.ui.components.CheckBox;
import haxe.ui.events.UIEvent;
import funkin.ui.haxeui.EditorWidget.EditorTextStyle;

class EditorCheckBox extends EditorWidget<CheckBox>
{
	public static final CLICK_EVENT:String = funkin.ui.psych.PsychUICheckBox.CLICK_EVENT;

	public var onClick:Void->Void;
	public var checked(get, set):Bool;
	public var label(get, set):String;
	public var text(default, null):EditorTextStyle;

	public function new(x:Float, y:Float, label:String, ?textWid:Int = 100, ?callback:Void->Void)
	{
		var box:CheckBox = new CheckBox();
		box.text = label;
		box.customStyle.fontSize = 11;
		if (textWid > 0) box.width = textWid + 20;
		super(x, y, box);
		onClick = callback;
		text = new EditorTextStyle(box);
		box.registerEvent(UIEvent.CHANGE, function(_)
		{
			if (silent) return;
			if (onClick != null) onClick();
			broadcast(CLICK_EVENT);
		});
	}

	function get_checked():Bool
		return component.selected;

	function set_checked(value:Bool):Bool
	{
		quietly(() -> component.selected = value);
		return value;
	}

	function get_label():String
		return component.text;

	function set_label(value:String):String
	{
		component.text = value;
		return value;
	}
}
