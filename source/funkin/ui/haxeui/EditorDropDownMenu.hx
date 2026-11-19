package funkin.ui.haxeui;

import haxe.ui.components.DropDown;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.UIEvent;

class EditorDropDownMenu extends EditorWidget<DropDown>
{
	public static final CLICK_EVENT:String = funkin.ui.psych.PsychUIDropDownMenu.CLICK_EVENT;

	public var onSelect:Int->String->Void;
	public var list(default, set):Array<String> = [];
	public var selectedIndex(get, set):Int;
	public var selectedLabel(get, set):String;

	public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void, ?width:Float = 100)
	{
		var drop:DropDown = new DropDown();
		drop.width = width;
		drop.height = 22;
		drop.customStyle.fontSize = 11;
		drop.dropdownHeight = 220;
		drop.searchable = true;
		super(x, y, drop);
		onSelect = callback;
		this.list = list != null ? list : [];
		drop.registerEvent(UIEvent.CHANGE, function(_)
		{
			if (silent) return;
			var index:Int = drop.selectedIndex;
			if (index < 0 || index >= this.list.length) return;
			if (onSelect != null) onSelect(index, this.list[index]);
			broadcast(CLICK_EVENT);
		});
	}

	function set_list(value:Array<String>):Array<String>
	{
		if (value == null) value = [];
		var previous:String = list != null && component.selectedIndex > -1 && component.selectedIndex < list.length ? list[component.selectedIndex] : null;
		list = value;
		var source:ArrayDataSource<Dynamic> = new ArrayDataSource<Dynamic>();
		for (item in value) source.add({text: item});
		quietly(function()
		{
			component.dataSource = source;
			var index:Int = previous != null ? value.indexOf(previous) : -1;
			component.selectedIndex = index > -1 ? index : (value.length > 0 ? 0 : -1);
		});
		return value;
	}

	function get_selectedIndex():Int
		return component.selectedIndex;

	function set_selectedIndex(value:Int):Int
	{
		if (value >= list.length) value = list.length - 1;
		quietly(() -> component.selectedIndex = value);
		return value;
	}

	function get_selectedLabel():String
	{
		var index:Int = component.selectedIndex;
		return index > -1 && index < list.length ? list[index] : null;
	}

	function set_selectedLabel(value:String):String
	{
		var index:Int = value != null ? list.indexOf(value) : -1;
		quietly(function()
		{
			component.selectedIndex = index;
			if (index < 0) component.text = value != null ? value : '';
		});
		return value;
	}
}
