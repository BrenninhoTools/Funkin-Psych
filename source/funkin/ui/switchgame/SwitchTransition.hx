package funkin.ui.switchgame;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.Lib;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

class SwitchTransition extends Sprite
{
	public static var current(default, null):SwitchTransition;

	var stageWidth:Float;
	var stageHeight:Float;
	var shade:Shape;
	var topPanel:Shape;
	var bottomPanel:Shape;
	var label:TextField;
	var title:TextField;
	var barBack:Shape;
	var barFill:Shape;
	var curtain:Shape;
	var tweens:Array<FlxTween> = [];
	var timers:Array<FlxTimer> = [];
	var accent:FlxColor;

	public var progress(default, set):Float = 0;

	function new(color:FlxColor)
	{
		super();
		accent = color;
		mouseEnabled = mouseChildren = false;
		stageWidth = Lib.current.stage.stageWidth;
		stageHeight = Lib.current.stage.stageHeight;

		shade = rect(0x000000, stageWidth, stageHeight);
		addChild(shade);

		var half:Float = Math.ceil(stageHeight / 2) + 1;
		topPanel = panel(color, half, true);
		bottomPanel = panel(color, half, false);
		bottomPanel.y = stageHeight - half;
		addChild(topPanel);
		addChild(bottomPanel);

		label = text(Std.int(stageHeight * 0.035), 0xFFFFFF);
		title = text(Std.int(stageHeight * 0.085), 0xFFFFFF);
		addChild(label);
		addChild(title);

		var barWidth:Float = stageWidth * 0.36;
		var barHeight:Float = Math.max(4, stageHeight * 0.012);
		barBack = rect(0x000000, barWidth, barHeight, 0.45);
		barFill = rect(0xFFFFFF, barWidth, barHeight);
		barBack.x = barFill.x = (stageWidth - barWidth) / 2;
		barBack.y = barFill.y = stageHeight * 0.64;
		barFill.scaleX = 0;
		addChild(barBack);
		addChild(barFill);

		curtain = rect(0x000000, stageWidth, stageHeight);
		curtain.alpha = 0;
		addChild(curtain);
	}

	public static function playOut(name:String, color:FlxColor, onFinish:Void->Void):SwitchTransition
	{
		cancelCurrent();
		var transition:SwitchTransition = new SwitchTransition(color);
		current = transition;
		Lib.current.stage.addChild(transition);
		transition.animateOut(name, onFinish);
		return transition;
	}

	public static function playIn(fromName:String, fromColor:FlxColor, toName:String, toColor:FlxColor, ?onFinish:Void->Void):SwitchTransition
	{
		cancelCurrent();
		var transition:SwitchTransition = new SwitchTransition(fromColor);
		current = transition;
		Lib.current.stage.addChild(transition);
		transition.animateIn(fromName, toName, toColor, onFinish);
		return transition;
	}

	public static function cancelCurrent()
	{
		if (current != null) current.finish();
	}

	function animateOut(name:String, onFinish:Void->Void)
	{
		shade.alpha = 0;
		topPanel.x = -stageWidth;
		bottomPanel.x = stageWidth;
		setTexts('SWITCHING TO', name.toUpperCase());
		label.alpha = title.alpha = 0;
		barBack.alpha = barFill.alpha = 0;
		var titleY:Float = title.y;
		title.y = titleY + stageHeight * 0.04;

		tween(shade, {alpha: 0.75}, 0.25, FlxEase.quadOut);
		tween(topPanel, {x: 0}, 0.5, FlxEase.expoOut);
		tween(bottomPanel, {x: 0}, 0.5, FlxEase.expoOut, 0.06);
		tween(label, {alpha: 1}, 0.3, FlxEase.quadOut, 0.3);
		tween(title, {alpha: 1, y: titleY}, 0.4, FlxEase.backOut, 0.35);
		tween(barBack, {alpha: 1}, 0.2, FlxEase.quadOut, 0.45);
		tween(barFill, {alpha: 1}, 0.2, FlxEase.quadOut, 0.45);
		tweens.push(FlxTween.num(0, 1, 0.75, {ease: FlxEase.sineInOut, startDelay: 0.5}, (value:Float) -> progress = value));
		tween(curtain, {alpha: 1}, 0.25, FlxEase.quadIn, 1.3);
		wait(1.6, function()
		{
			if (onFinish != null) onFinish();
		});
	}

	public function fail(message:String, ?onClosed:Void->Void)
	{
		stopAll();
		setTexts('COULD NOT SWITCH', message);
		label.alpha = title.alpha = 1;
		var size:Int = Std.int(stageHeight * 0.035);
		var format:TextFormat = title.defaultTextFormat;
		format.size = size;
		title.defaultTextFormat = format;
		title.setTextFormat(format);
		layoutTexts();
		curtain.alpha = 0;
		barBack.alpha = barFill.alpha = 0;
		tween(topPanel, {x: -stageWidth}, 0.45, FlxEase.expoIn, 1.6);
		tween(bottomPanel, {x: stageWidth}, 0.45, FlxEase.expoIn, 1.65);
		tween(label, {alpha: 0}, 0.2, FlxEase.quadIn, 1.6);
		tween(title, {alpha: 0}, 0.2, FlxEase.quadIn, 1.6);
		tween(shade, {alpha: 0}, 0.3, FlxEase.quadIn, 1.9);
		wait(2.25, function()
		{
			finish();
			if (onClosed != null) onClosed();
		});
	}

	function animateIn(fromName:String, toName:String, toColor:FlxColor, onFinish:Void->Void)
	{
		shade.alpha = 1;
		setTexts('SWITCHED FROM', fromName.toUpperCase());
		progress = 1;
		barBack.alpha = barFill.alpha = 0;

		wait(0.7, function()
		{
			recolor(toColor);
			setTexts('WELCOME TO', toName.toUpperCase());
		});
		var half:Float = topPanel.height;
		tween(label, {alpha: 0}, 0.2, FlxEase.quadIn, 1.25);
		tween(title, {alpha: 0}, 0.2, FlxEase.quadIn, 1.25);
		tween(topPanel, {y: -half}, 0.55, FlxEase.expoInOut, 1.3);
		tween(bottomPanel, {y: stageHeight}, 0.55, FlxEase.expoInOut, 1.3);
		tween(shade, {alpha: 0}, 0.45, FlxEase.quadOut, 1.4);
		wait(1.9, function()
		{
			finish();
			if (onFinish != null) onFinish();
		});
	}

	public function finish()
	{
		stopAll();
		if (parent != null) parent.removeChild(this);
		if (current == this) current = null;
	}

	function stopAll()
	{
		for (t in tweens) if (t != null) t.cancel();
		for (t in timers) if (t != null) t.cancel();
		tweens = [];
		timers = [];
	}

	function tween(target:Dynamic, values:Dynamic, duration:Float, ease:Float->Float, delay:Float = 0)
		tweens.push(FlxTween.tween(target, values, duration, {ease: ease, startDelay: delay}));

	function wait(time:Float, callback:Void->Void)
		timers.push(new FlxTimer().start(time, (_) -> callback()));

	function setTexts(top:String, main:String)
	{
		label.text = top;
		title.text = main;
		layoutTexts();
	}

	function layoutTexts()
	{
		title.x = (stageWidth - title.width) / 2;
		title.y = (stageHeight - title.height) / 2;
		label.x = (stageWidth - label.width) / 2;
		label.y = title.y - label.height;
	}

	function recolor(color:FlxColor)
	{
		accent = color;
		drawPanel(topPanel, color, topPanel.height, true);
		drawPanel(bottomPanel, color, bottomPanel.height, false);
	}

	function set_progress(value:Float):Float
	{
		progress = Math.max(0, Math.min(1, value));
		if (barFill != null) barFill.scaleX = progress;
		return progress;
	}

	static function rect(color:Int, width:Float, height:Float, alpha:Float = 1):Shape
	{
		var shape:Shape = new Shape();
		shape.graphics.beginFill(color, alpha);
		shape.graphics.drawRect(0, 0, width, height);
		shape.graphics.endFill();
		return shape;
	}

	function panel(color:FlxColor, height:Float, top:Bool):Shape
	{
		var shape:Shape = new Shape();
		drawPanel(shape, color, height, top);
		return shape;
	}

	function drawPanel(shape:Shape, color:FlxColor, height:Float, top:Bool)
	{
		var dark:FlxColor = color.getDarkened(0.35);
		var g = shape.graphics;
		g.clear();
		g.beginFill(color.to24Bit(), 1);
		g.drawRect(0, 0, stageWidth, height);
		g.endFill();
		var stripe:Float = Math.max(3, stageHeight * 0.01);
		g.beginFill(dark.to24Bit(), 1);
		g.drawRect(0, top ? height - stripe : 0, stageWidth, stripe);
		g.endFill();
		var step:Float = stageHeight * 0.08;
		g.beginFill(0xFFFFFF, 0.08);
		var offset:Float = top ? 0 : step;
		var x:Float = -height + offset;
		while (x < stageWidth)
		{
			g.moveTo(x, height);
			g.lineTo(x + height, 0);
			g.lineTo(x + height + step * 0.5, 0);
			g.lineTo(x + step * 0.5, height);
			g.lineTo(x, height);
			x += step * 1.5;
		}
		g.endFill();
	}

	static function text(size:Int, color:Int):TextField
	{
		var field:TextField = new TextField();
		field.selectable = false;
		field.mouseEnabled = false;
		field.embedFonts = false;
		field.autoSize = TextFieldAutoSize.CENTER;
		var format:TextFormat = new TextFormat(fontName(), size, color, true);
		format.align = TextFormatAlign.CENTER;
		field.defaultTextFormat = format;
		return field;
	}

	static function fontName():String
	{
		try
		{
			var font = openfl.utils.Assets.getFont(Paths.font('vcr.ttf'));
			if (font != null && font.fontName != null) return font.fontName;
		}
		catch (e:Dynamic) {}
		return '_sans';
	}
}
