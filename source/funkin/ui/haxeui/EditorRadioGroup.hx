package funkin.ui.haxeui;

import haxe.ui.components.OptionBox;
import haxe.ui.containers.Box;
import haxe.ui.containers.HBox;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.events.UIEvent;
import funkin.ui.haxeui.EditorWidget.EditorTextStyle;

class EditorRadioGroup extends EditorWidget<Component>
{
	public static final CLICK_EVENT:String = funkin.ui.psych.PsychUIRadioGroup.CLICK_EVENT;
	static var groupCounter:Int = 0;

	public var onClick:Void->Void;
	public var labels(default, set):Array<String> = [];
	public var radios(default, null):Array<EditorRadioItem> = [];
	public var checked(default, set):Int = -1;
	public var checkedRadio(get, set):EditorRadioItem;
	public var space(default, null):Float;
	public var maxItems(default, null):Int;
	public var stackHorizontal(default, null):Bool;
	public var textWidth(default, null):Int;

	var itemBox:Box;
	var groupName:String;

	public function new(x:Float, y:Float, labels:Array<String>, space:Float = 25, maxItems:Int = 0, ?isHorizontal:Bool = false, ?textWidth:Int = 100)
	{
		EditorUI.ensureToolkit();
		this.space = space;
		this.maxItems = maxItems;
		this.stackHorizontal = isHorizontal;
		this.textWidth = textWidth;
		groupName = 'editorRadio${groupCounter++}';

		itemBox = isHorizontal ? new HBox() : new VBox();
		itemBox.customStyle.horizontalSpacing = isHorizontal ? space : 0;
		itemBox.customStyle.verticalSpacing = isHorizontal ? 0 : Math.max(0, space - 20);

		var root:Component = itemBox;
		if (!isHorizontal && maxItems > 0)
		{
			var scroll:ScrollView = new ScrollView();
			scroll.width = textWidth + 40;
			scroll.height = maxItems * space;
			scroll.addComponent(itemBox);
			root = scroll;
		}
		super(x, y, root);
		this.labels = labels != null ? labels : [];
	}

	public function updateRadioItems()
	{
		for (num => radio in radios)
		{
			radio.index = num;
			quietly(() -> radio.option.selected = num == checked);
		}
	}

	function set_labels(value:Array<String>):Array<String>
	{
		if (value == null) value = [];
		labels = value;
		for (radio in radios) itemBox.removeComponent(radio.option);
		radios = [];
		for (num => label in value)
		{
			var option:OptionBox = new OptionBox();
			option.componentGroup = groupName;
			option.text = label;
			option.customStyle.fontSize = 11;
			if (!stackHorizontal) option.width = textWidth + 20;
			var item:EditorRadioItem = new EditorRadioItem(this, option, num);
			option.registerEvent(UIEvent.CHANGE, function(_)
			{
				if (silent || !option.selected) return;
				@:bypassAccessor checked = item.index;
				if (onClick != null) onClick();
				broadcast(CLICK_EVENT);
			});
			radios.push(item);
			itemBox.addComponent(option);
		}
		if (checked >= value.length) checked = value.length - 1;
		else updateRadioItems();
		return value;
	}

	function set_checked(value:Int):Int
	{
		checked = Std.int(Math.max(-1, Math.min(value, radios.length - 1)));
		updateRadioItems();
		return checked;
	}

	function get_checkedRadio():EditorRadioItem
		return checked > -1 && checked < radios.length ? radios[checked] : null;

	function set_checkedRadio(value:EditorRadioItem):EditorRadioItem
	{
		checked = value != null ? radios.indexOf(value) : -1;
		return value;
	}
}

class EditorRadioItem
{
	public var parent(default, null):EditorRadioGroup;
	public var option(default, null):OptionBox;
	public var index:Int;
	public var label(get, set):String;
	public var text(default, null):EditorTextStyle;

	public function new(parent:EditorRadioGroup, option:OptionBox, index:Int)
	{
		this.parent = parent;
		this.option = option;
		this.index = index;
		text = new EditorTextStyle(option);
	}

	function get_label():String
		return option.text;

	function set_label(value:String):String
	{
		option.text = value;
		return value;
	}
}
