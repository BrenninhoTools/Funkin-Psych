package funkin.ui.freeplay;

enum FreeplayAnimateAlign
{
	NONE;
	TOP_LEFT;
	TOP_RIGHT(width:Float);
}

class FreeplayAnimate extends FlxAnimate
{
	static var measureCamera:FlxCamera;

	public var align:FreeplayAnimateAlign = NONE;

	var aligned:Bool = false;

	public function new(x:Float = 0, y:Float = 0, ?folder:String, ?align:FreeplayAnimateAlign)
	{
		super(x, y);
		if (folder != null) Paths.loadAnimateAtlas(this, folder);
		if (align != null) this.align = align;
		antialiasing = Save.data.antialiasing;
	}

	public function realign()
		aligned = false;

	override function draw()
	{
		if (!aligned && align != NONE && visible && alpha > 0 && anim.curInstance != null && anim.curSymbol != null)
		{
			aligned = true;
			measure();
		}
		super.draw();
	}

	function measure()
	{
		if (measureCamera == null) measureCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		var previous:Array<FlxCamera> = @:privateAccess _cameras;
		cameras = [measureCamera];
		super.draw();
		@:privateAccess _cameras = previous;
		@:privateAccess measureCamera.clearDrawStack();

		if (width <= 0 && height <= 0) return;
		switch (align)
		{
			case TOP_LEFT:
				x -= relativeX;
				y -= relativeY;
			case TOP_RIGHT(target):
				x -= relativeX + width - target;
				y -= relativeY;
			case NONE:
		}
	}
}
