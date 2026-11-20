package funkin.ui.freeplay;

import flixel.util.FlxSort;

class BGScrollingText extends FlxText
{
	public var widthShit:Float = FlxG.width;
	public var placementOffset:Float = 20;
	public var speed:Float = 1;

	var textPositions:Array<FlxPoint> = [];
	var positionCache:FlxPoint;

	public function new(x:Float, y:Float, text:String, widthShit:Float = 100, bold:Bool = false, size:Int = 48)
	{
		super(x, y, 0, text, size);
		positionCache = FlxPoint.get(x, y);
		font = Paths.font(bold ? '5by7_b.ttf' : '5by7.ttf');
		this.bold = bold;
		antialiasing = Save.data.antialiasing;
		this.widthShit = widthShit;
		rebuildPositions();
	}

	public function updateText(newText:String)
	{
		text = newText;
		rebuildPositions();
	}

	function rebuildPositions()
	{
		@:privateAccess regenGraphic();
		for (point in textPositions) point.put();
		textPositions = [];
		var needed:Int = Math.ceil(widthShit / Math.max(1, frameWidth)) + 1;
		for (i in 0...needed) textPositions.push(FlxPoint.get((i * frameWidth) + (i * 20), 0));
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (textPositions.length < 1) return;
		for (point in textPositions)
		{
			point.x -= speed * (elapsed / (1 / 60));
			if (speed > 0)
			{
				if (point.x < -frameWidth)
				{
					point.x = textPositions[textPositions.length - 1].x + frameWidth + placementOffset;
					sortPositions();
				}
			}
			else if (point.x > frameWidth * 2)
			{
				point.x = textPositions[0].x - frameWidth - placementOffset;
				sortPositions();
			}
		}
	}

	override function draw():Void
	{
		positionCache.set(x, y);
		for (point in textPositions)
		{
			setPosition(positionCache.x + point.x, positionCache.y + point.y);
			super.draw();
		}
		setPosition(positionCache.x, positionCache.y);
	}

	inline function sortPositions()
		textPositions.sort(function(a:FlxPoint, b:FlxPoint) return FlxSort.byValues(FlxSort.ASCENDING, a.x, b.x));

	override function destroy()
	{
		for (point in textPositions) point.put();
		textPositions = [];
		positionCache = flixel.util.FlxDestroyUtil.put(positionCache);
		super.destroy();
	}
}
