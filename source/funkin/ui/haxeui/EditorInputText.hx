package funkin.ui.haxeui;

import haxe.ui.components.TextField;
import haxe.ui.events.UIEvent;
import haxe.ui.events.FocusEvent;
import funkin.ui.psych.PsychUIInputText.CaseMode;
import funkin.ui.psych.PsychUIInputText.FilterMode;

class EditorInputText extends EditorWidget<TextField>
{
	public static final CHANGE_EVENT:String = funkin.ui.psych.PsychUIInputText.CHANGE_EVENT;

	public static var focusOn(get, set):Dynamic;
	static function get_focusOn():Dynamic
	{
		var owner:Dynamic = EditorUI.focusedOwner();
		return owner != null ? owner : funkin.ui.psych.PsychUIInputText.focusOn;
	}

	static function set_focusOn(value:Dynamic):Dynamic
	{
		if (value == null)
		{
			EditorUI.clearFocus();
			funkin.ui.psych.PsychUIInputText.focusOn = null;
		}
		else if (Std.isOfType(value, EditorInputText)) (cast value:EditorInputText).component.focus = true;
		return value;
	}

	public var onChange:String->String->Void;
	public var unfocus:Void->Void;
	public var text(get, set):String;
	public var maxLength(default, set):Int = 0;
	public var forceCase(default, set):CaseMode = ALL_CASES;
	public var filterMode(default, set):FilterMode = NO_FILTER;
	public var customFilterPattern(default, set):EReg;
	public var fieldWidth(get, set):Int;

	var lastText:String = '';

	public function new(x:Float = 0, y:Float = 0, wid:Int = 100, ?text:String = '', size:Int = 8)
	{
		var field:TextField = new TextField();
		field.width = wid;
		field.height = size + 14;
		field.customStyle.fontSize = size + 3;
		super(x, y, field);
		this.text = text != null ? text : '';
		field.registerEvent(UIEvent.CHANGE, function(_) onTextChanged());
		field.registerEvent(FocusEvent.FOCUS_OUT, function(_) if (unfocus != null) unfocus());
	}

	function onTextChanged()
	{
		if (silent) return;
		var filtered:String = applyFilters(component.text);
		if (filtered != component.text)
		{
			quietly(() -> component.text = filtered);
		}
		if (filtered == lastText) return;
		var old:String = lastText;
		lastText = filtered;
		if (onChange != null) onChange(old, filtered);
		broadcast(CHANGE_EVENT);
	}

	function applyFilters(value:String):String
	{
		if (value == null) return '';
		switch (forceCase)
		{
			case UPPER_CASE: value = value.toUpperCase();
			case LOWER_CASE: value = value.toLowerCase();
			default:
		}
		var pattern:EReg = switch (filterMode)
		{
			case ONLY_ALPHA: ~/[^a-zA-Z]/g;
			case ONLY_NUMERIC: ~/[^0-9.\-]/g;
			case ONLY_ALPHANUMERIC: ~/[^a-zA-Z0-9]/g;
			case ONLY_HEXADECIMAL: ~/[^a-fA-F0-9]/g;
			case CUSTOM_FILTER: customFilterPattern;
			default: null;
		};
		if (pattern != null) value = pattern.replace(value, '');
		if (maxLength > 0 && value.length > maxLength) value = value.substr(0, maxLength);
		return value;
	}

	function get_text():String
		return component.text != null ? component.text : '';

	function set_text(value:String):String
	{
		if (value == null) value = '';
		lastText = value;
		quietly(() -> component.text = value);
		return value;
	}

	function set_maxLength(value:Int):Int
	{
		maxLength = value;
		component.maxChars = value > 0 ? value : -1;
		return value;
	}

	function set_forceCase(value:CaseMode):CaseMode
	{
		forceCase = value;
		text = applyFilters(text);
		return value;
	}

	function set_filterMode(value:FilterMode):FilterMode
	{
		filterMode = value;
		text = applyFilters(text);
		return value;
	}

	function set_customFilterPattern(value:EReg):EReg
	{
		customFilterPattern = value;
		if (filterMode == CUSTOM_FILTER) text = applyFilters(text);
		return value;
	}

	function get_fieldWidth():Int
		return Std.int(component.width);

	function set_fieldWidth(value:Int):Int
	{
		component.width = value;
		return value;
	}
}
