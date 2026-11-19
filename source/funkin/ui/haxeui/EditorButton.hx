package funkin.ui.haxeui;

import haxe.ui.components.Button;
import haxe.ui.events.MouseEvent;
import funkin.ui.haxeui.EditorWidget.EditorButtonStyle;
import funkin.ui.haxeui.EditorWidget.EditorTextStyle;

class EditorButton extends EditorWidget<Button>
{
	public static final CLICK_EVENT:String = funkin.ui.psych.PsychUIButton.CLICK_EVENT;

	public var onClick:Void->Void;
	public var label(get, set):String;
	public var text(default, null):EditorTextStyle;
	public var normalStyle(default, null):EditorButtonStyle;

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void, ?wid:Int = 80, ?hei:Int = 20)
	{
		var button:Button = new Button();
		button.text = label;
		button.width = wid;
		button.height = hei;
		button.customStyle.fontSize = 11;
		super(x, y, button);
		this.onClick = onClick;
		text = new EditorTextStyle(button);
		normalStyle = new EditorButtonStyle(button);
		button.registerEvent(MouseEvent.CLICK, function(_)
		{
			if (onClick != null) onClick();
			broadcast(CLICK_EVENT);
		});
	}

	function get_label():String
		return component.text;

	function set_label(value:String):String
	{
		component.text = value;
		return value;
	}
}
