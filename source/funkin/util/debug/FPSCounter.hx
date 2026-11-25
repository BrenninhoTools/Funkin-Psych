package funkin.util.debug;

import flixel.FlxG;
import flixel.util.FlxStringUtil;
import funkin.audio.AudioMixer;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

enum abstract FPSStyle(String) from String to String
{
	var DISABLE = 'Disable';
	var SIMPLE = 'Simple';
	var ADVANCED = 'Advanced';

	public static final ALL:Array<String> = [DISABLE, SIMPLE, ADVANCED];

	public static function resolve(value:String):FPSStyle
	{
		if (value == null) return SIMPLE;
		for (style in ALL)
			if (style.toLowerCase() == value.toLowerCase()) return style;
		return value.toLowerCase().startsWith('adv') ? ADVANCED : SIMPLE;
	}
}

class FPSCounter extends Sprite
{
	public static inline final SEPARATOR:String = '  •  ';
	public static inline final HISTORY:Int = 90;

	public var style(default, set):FPSStyle = SIMPLE;
	public var currentFPS(default, null):Int = 0;
	public var memoryMegas(get, never):Float;
	public var memoryPeak(default, null):Float = 0;

	var hardwareLine:String = '';
	var lastHardwareRefresh:Float = -10000;
	public var textColor(get, set):Int;
	public var text(get, set):String;
	public var padding:Float = 6;
	public var barAlpha(default, set):Float = 0.6;
	public var graphWidth:Float = 300;
	public var graphHeight:Float = 54;
	public var meterWidth:Float = 7;

	public var label(default, null):TextField;
	public var mixerLabel(default, null):TextField;
	public var bar(default, null):Shape;
	public var graph(default, null):Shape;

	var times:Array<Float> = [];
	var lastRefresh:Float = 0;
	var systemName:String;
	var levels:Array<Float> = [0, 0, 0, 0];
	var smoothed:Array<Float> = [0, 0, 0, 0];
	var history:Array<Array<Float>> = [for (_ in 0...4) [for (_ in 0...HISTORY) 0.0]];

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF, ?style:FPSStyle)
	{
		super();
		this.x = x;
		this.y = y;
		mouseEnabled = mouseChildren = false;

		bar = new Shape();
		addChild(bar);

		label = makeField(color);
		label.text = 'FPS: 0';
		addChild(label);

		mixerLabel = makeField(color);
		addChild(mixerLabel);

		graph = new Shape();
		addChild(graph);

		systemName = describeSystem();
		this.style = style != null ? style : SIMPLE;
		addEventListener(openfl.events.Event.ENTER_FRAME, onEnterFrame);
	}

	function makeField(color:Int):TextField
	{
		var field:TextField = new TextField();
		field.selectable = false;
		field.mouseEnabled = false;
		field.defaultTextFormat = new TextFormat("_sans", 14, color);
		field.autoSize = TextFieldAutoSize.LEFT;
		field.multiline = true;
		return field;
	}

	function onEnterFrame(_)
	{
		if (style == DISABLE) return;
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		if (now - lastRefresh < 50) return;
		lastRefresh = now;

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		var memory:Float = memoryMegas;
		if (memory > memoryPeak) memoryPeak = memory;
		if (style == ADVANCED) sampleMixer();
		updateText();
		redrawBar();
	}

	function sampleMixer()
	{
		AudioMixer.sample(levels);
		for (i in 0...levels.length)
		{
			smoothed[i] = levels[i] >= smoothed[i] ? levels[i] : Math.max(levels[i], smoothed[i] * 0.82);
			var line:Array<Float> = history[i];
			line.shift();
			line.push(smoothed[i]);
		}
	}

	public dynamic function updateText():Void
	{
		var rework:String = funkin.util.FPSManager.describe();
		var fps:String = 'FPS: $currentFPS' + (rework.length > 0 ? ' ($rework)' : '');
		var memory:String = 'Memory: ${FlxStringUtil.formatBytes(memoryMegas)} / ${FlxStringUtil.formatBytes(memoryPeak)}';
		var lines:Array<String> = [[fps, memory].join(SEPARATOR)];
		if (style == ADVANCED)
		{
			lines.push(['Task: ${describeTask()}', 'System: $systemName'].join(SEPARATOR));
			refreshHardware();
			if (hardwareLine.length > 0) lines.push(hardwareLine);
			if (funkin.optimize.Optimizer.enabled && funkin.optimize.Optimizer.frameTimeMs() > 0)
			{
				var frame:Array<String> = [
					'Frame: ${FlxMath.roundDecimal(funkin.optimize.Optimizer.frameTimeMs(), 2)}ms',
					'Work: ${FlxMath.roundDecimal(funkin.optimize.Optimizer.workTimeMs(), 2)}ms',
					'1% Low: ${Math.round(funkin.optimize.Optimizer.lowFps())}'
				];
				if (funkin.optimize.Optimizer.thermal != UNKNOWN) frame.push('Thermal: ${funkin.optimize.Optimizer.thermalName()}');
				lines.push(frame.join(SEPARATOR));
			}
		}
		label.text = lines.join('\n');
		label.textColor = currentFPS < funkin.util.FPSManager.warningFPS() ? 0xFFFF4040 : 0xFFFFFFFF;
	}

	function refreshHardware():Void
	{
		var now:Float = haxe.Timer.stamp() * 1000;
		if (now - lastHardwareRefresh < 1000) return;
		lastHardwareRefresh = now;
		var parts:Array<String> = [];
		var process:Float = lime.system.Hardware.processMemory;
		if (process > 0) parts.push('Process: ${FlxStringUtil.formatBytes(process)}');
		var cores:Int = lime.system.Hardware.cpuCount;
		var ram:Int = lime.system.Hardware.systemRAM;
		if (cores > 0) parts.push('CPU: $cores threads' + (ram > 0 ? ', ${Math.round(ram / 102.4) / 10} GB RAM' : ''));
		if (lime.system.Battery.hasBattery)
		{
			var percent:Int = lime.system.Battery.percent;
			parts.push('Battery: ' + (percent >= 0 ? '$percent% ' : '') + lime.system.Battery.state.toString());
		}
		hardwareLine = parts.join(SEPARATOR);
	}

	public function redrawBar()
	{
		label.x = padding;
		label.y = padding * 0.5;
		var width:Float = label.width;
		var height:Float = label.height;

		var advanced:Bool = style == ADVANCED;
		mixerLabel.visible = graph.visible = advanced;
		if (advanced)
		{
			mixerLabel.x = padding;
			mixerLabel.y = label.y + label.height;
			graph.x = padding;
			graph.y = mixerLabel.y + mixerLabel.height + 2;
			var graphSize:Float = Math.max(graphWidth, Math.max(label.width, mixerLabel.width));
			drawGraph(graphSize);
			width = Math.max(width, graphSize);
			height = graph.y + graphHeight - label.y;
		}

		bar.graphics.clear();
		bar.graphics.beginFill(0x000000, barAlpha);
		bar.graphics.drawRect(0, 0, width + padding * 2, height + padding);
		bar.graphics.endFill();
	}

	function updateMixerLabel()
	{
		var legend:Array<String> = [for (channel in AudioMixer.CHANNELS) '<font color="#${StringTools.hex(channel.color, 6)}">${channel.name}</font>'];
		mixerLabel.htmlText = 'Audio Mixer: ' + legend.join(' ');
	}

	function drawGraph(width:Float)
	{
		var g = graph.graphics;
		g.clear();
		var meters:Float = AudioMixer.CHANNELS.length * (meterWidth + 2);
		var plotWidth:Float = width - meters - 4;

		g.beginFill(0xFFFFFF, 0.06);
		g.drawRect(0, 0, plotWidth, graphHeight);
		g.endFill();
		g.lineStyle(1, 0xFFFFFF, 0.12);
		for (step in 1...4)
		{
			var lineY:Float = graphHeight * step / 4;
			g.moveTo(0, lineY);
			g.lineTo(plotWidth, lineY);
		}

		var stepX:Float = plotWidth / (HISTORY - 1);
		for (i in 0...AudioMixer.CHANNELS.length)
		{
			var line:Array<Float> = history[i];
			g.lineStyle(i == AudioMixer.CHANNELS.length - 1 ? 1.5 : 1, AudioMixer.CHANNELS[i].color, i == AudioMixer.CHANNELS.length - 1 ? 0.9 : 0.75);
			for (p in 0...line.length)
			{
				var px:Float = p * stepX;
				var py:Float = graphHeight - line[p] * (graphHeight - 2) - 1;
				if (p == 0) g.moveTo(px, py);
				else g.lineTo(px, py);
			}
		}
		g.lineStyle();

		var meterX:Float = plotWidth + 4;
		for (i in 0...AudioMixer.CHANNELS.length)
		{
			var color:Int = AudioMixer.CHANNELS[i].color;
			g.beginFill(0xFFFFFF, 0.08);
			g.drawRect(meterX, 0, meterWidth, graphHeight);
			g.endFill();
			var level:Float = Math.min(1, smoothed[i]);
			var fill:Float = level * graphHeight;
			g.beginFill(level > 0.95 ? 0xFF4040 : color, 0.9);
			g.drawRect(meterX, graphHeight - fill, meterWidth, fill);
			g.endFill();
			meterX += meterWidth + 2;
		}
	}

	public function resetMixer()
	{
		for (i in 0...smoothed.length)
		{
			smoothed[i] = 0;
			levels[i] = 0;
			for (p in 0...HISTORY) history[i][p] = 0;
		}
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

	function set_style(value:FPSStyle):FPSStyle
	{
		style = FPSStyle.resolve(value);
		visible = style != DISABLE;
		if (style == ADVANCED) updateMixerLabel();
		else resetMixer();
		lastRefresh = 0;
		if (label != null && style != DISABLE)
		{
			updateText();
			redrawBar();
		}
		return style;
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
