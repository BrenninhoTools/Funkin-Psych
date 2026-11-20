package funkin.ui.freeplay;

import openfl.display.BlendMode;

enum RankType
{
	LOSS;
	GOOD;
	GREAT;
	EXCELLENT;
	PERFECT;
	PERFECT_GOLD;
}

class FreeplayRank extends FlxSprite
{
	public var rank(default, set):Null<RankType> = null;

	public function new(x:Float, y:Float)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas('freeplay/rankbadges');
		animation.addByPrefix('PERFECT', 'PERFECT rank0', 24, false);
		animation.addByPrefix('EXCELLENT', 'EXCELLENT rank0', 24, false);
		animation.addByPrefix('GOOD', 'GOOD rank0', 24, false);
		animation.addByPrefix('PERFECTSICK', 'PERFECT rank GOLD', 24, false);
		animation.addByPrefix('GREAT', 'GREAT rank0', 24, false);
		animation.addByPrefix('LOSS', 'LOSS rank0', 24, false);
		blend = BlendMode.ADD;
		antialiasing = Save.data.antialiasing;
		rank = null;
		scale.set(0.9, 0.9);
		updateHitbox();
	}

	public static function colorOf(rank:Null<RankType>):FlxColor
	{
		return switch (rank)
		{
			case PERFECT_GOLD: 0xFFFFB619;
			case PERFECT: 0xFFFF58B4;
			case EXCELLENT: 0xFFFDCB42;
			case GREAT: 0xFFEAF6FF;
			case GOOD: 0xFFEF8764;
			default: 0xFF6044FF;
		}
	}

	function set_rank(value:Null<RankType>):Null<RankType>
	{
		rank = value;
		if (value == null)
		{
			visible = false;
			return value;
		}

		visible = true;
		animation.play(switch (value)
		{
			case PERFECT_GOLD: 'PERFECTSICK';
			case PERFECT: 'PERFECT';
			case EXCELLENT: 'EXCELLENT';
			case GREAT: 'GREAT';
			case GOOD: 'GOOD';
			case LOSS: 'LOSS';
		}, true);
		centerOffsets(false);
		if (value == GOOD || value == GREAT) offset.y -= 8;
		updateHitbox();
		return value;
	}
}
