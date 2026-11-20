package funkin.ui.freeplay;

import funkin.flxanimate.PsychFlxAnimate.AtlasAlign;

typedef FreeplayAnimateAlign = AtlasAlign;

class FreeplayAnimate extends FlxAnimate
{
	public function new(x:Float = 0, y:Float = 0, ?folder:String, ?align:AtlasAlign)
	{
		super(x, y);
		if (folder != null) Paths.loadAnimateAtlas(this, folder);
		if (align != null) this.align = align;
		antialiasing = Save.data.antialiasing;
	}
}
