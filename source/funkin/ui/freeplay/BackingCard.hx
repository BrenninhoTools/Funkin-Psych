package funkin.ui.freeplay;

import flixel.util.FlxSpriteUtil;
import funkin.ui.freeplay.FreeplayState.ExitMoverData;
import openfl.display.BlendMode;

class BackingCard extends FlxSpriteGroup
{
	public var backingTextYeah:FlxAnimate;
	public var orangeBackShit:FlxSprite;
	public var alsoOrangeLOL:FlxSprite;
	public var pinkBack:FlxSprite;
	public var confirmGlow:FlxSprite;
	public var confirmGlow2:FlxSprite;
	public var confirmTextGlow:FlxSprite;
	public var cardGlow:FlxSprite;

	public var instance:FreeplayState;

	var scrollingTexts:Array<BGScrollingText> = [];
	var glow:FlxSprite;
	var glowDark:FlxSprite;
	var beatFreqList:Array<Int> = [1, 2, 4, 8];
	var texts:Array<String>;

	public function new(instance:FreeplayState, texts:Array<String>, offsetX:Float)
	{
		super();
		this.instance = instance;
		this.texts = texts;

		cardGlow = new FlxSprite(-30, -30).loadGraphic(Paths.image('freeplay/cardGlow'));
		confirmGlow = new FlxSprite(offsetX - 30, 240).loadGraphic(Paths.image('freeplay/confirmGlow'));
		confirmTextGlow = new FlxSprite(offsetX - 8, 115).loadGraphic(Paths.image('freeplay/glowingText'));
		pinkBack = new FlxSprite().loadGraphic(Paths.image('freeplay/pinkBack'));
		orangeBackShit = new FlxSprite(84, 440).makeGraphic(Std.int(pinkBack.width), 75, 0xFFFEDA00, true);
		alsoOrangeLOL = new FlxSprite(0, orangeBackShit.y).makeGraphic(100, Std.int(orangeBackShit.height), 0xFFFFD400);
		confirmGlow2 = new FlxSprite(confirmGlow.x, confirmGlow.y).loadGraphic(Paths.image('freeplay/confirmGlow2'));

		backingTextYeah = new FlxAnimate(offsetX - 320, 120);
		Paths.loadAnimateAtlas(backingTextYeah, 'freeplay/backing-text-yeah');
		backingTextYeah.anim.loopType = flxanimate.data.AnimationData.Loop.PlayOnce;
		backingTextYeah.anim.pause();

		pinkBack.color = 0xFFFFD4E9;
		pinkBack.x -= pinkBack.width;
		FlxTween.tween(pinkBack, {x: 0}, 0.6, {ease: FlxEase.quartOut});

		add(pinkBack);
		add(orangeBackShit);
		add(alsoOrangeLOL);
		FlxSpriteUtil.alphaMaskFlxSprite(orangeBackShit, pinkBack, orangeBackShit);
		orangeBackShit.visible = alsoOrangeLOL.visible = false;

		confirmTextGlow.blend = BlendMode.ADD;
		confirmTextGlow.visible = false;
		confirmGlow.blend = BlendMode.ADD;
		confirmGlow.visible = false;
		confirmGlow2.visible = false;
		add(confirmGlow2);
		add(confirmGlow);
		add(confirmTextGlow);
		add(backingTextYeah);

		var funnyScroll:BGScrollingText = scroller(0, 220, 1, FlxG.width / 2, false, 60, 0xFFFF9963, -3.8);
		var funnyScroll2:BGScrollingText = scroller(0, 335, 1, FlxG.width / 2, false, 60, 0xFFFF9963, -3.8);
		var moreWays:BGScrollingText = scroller(0, 160, 2, FlxG.width, true, 43, 0xFFFFF383, 6.8);
		var moreWays2:BGScrollingText = scroller(0, 397, 2, FlxG.width, true, 43, 0xFFFFF383, 6.8);
		var txtNuts:BGScrollingText = scroller(0, 285, 3, FlxG.width / 2, true, 43, 0xFFFFFFFF, 3.5);
		var funnyScroll3:BGScrollingText = scroller(0, orangeBackShit.y + 10, 1, FlxG.width / 2, false, 60, 0xFFFEA400, -3.8);
		for (text in [moreWays, funnyScroll, txtNuts, funnyScroll2, moreWays2, funnyScroll3]) add(text);

		glowDark = new FlxSprite(offsetX - 300, 330).loadGraphic(Paths.image('freeplay/beatglow'));
		glowDark.blend = BlendMode.MULTIPLY;
		glowDark.visible = false;
		add(glowDark);
		glow = new FlxSprite(offsetX - 300, 330).loadGraphic(Paths.image('freeplay/beatglow'));
		glow.blend = BlendMode.ADD;
		glow.visible = false;
		add(glow);

		cardGlow.blend = BlendMode.ADD;
		cardGlow.visible = false;
		add(cardGlow);

		for (member in members)
			if (member != null) member.antialiasing = Save.data.antialiasing;
	}

	function scroller(x:Float, y:Float, textIndex:Int, width:Float, bold:Bool, size:Int, color:FlxColor, speed:Float):BGScrollingText
	{
		var text:BGScrollingText = new BGScrollingText(x, y, textAt(textIndex), width, bold, size);
		text.color = color;
		text.speed = speed;
		text.visible = false;
		scrollingTexts.push(text);
		return text;
	}

	inline function textAt(index:Int):String
		return texts != null && texts.length >= index && texts[index - 1] != null ? texts[index - 1] : '';

	public function setSpecial(special:Bool)
	{
		for (i => text in scrollingTexts)
		{
			var index:Int = [1, 1, 2, 2, 3, 1][i];
			text.updateText(special ? (index == 1 ? 'SPECIAL SPECIAL' : 'SPECIAL') : textAt(index));
		}
	}

	public function applyExitMovers(exitMovers:ExitMoverData):Void
	{
		exitMovers.set([pinkBack, orangeBackShit, alsoOrangeLOL], {x: -pinkBack.width, y: pinkBack.y, speed: 0.4, wait: 0});
		for (i => text in scrollingTexts)
		{
			exitMovers.set([text], {x: text.speed > 0 ? FlxG.width * 2 : -text.width * 2, speed: [0.4, 0.5, 0.4, 0.4, 0.4, 0.3][i]});
		}
	}

	public function skipIntroTween():Void
	{
		FlxTween.cancelTweensOf(pinkBack);
		pinkBack.x = 0;
	}

	public function introDone():Void
	{
		pinkBack.color = 0xFFFFD863;
		orangeBackShit.visible = alsoOrangeLOL.visible = true;
		cardGlow.visible = true;
		FlxTween.tween(cardGlow, {alpha: 0, "scale.x": 1.2, "scale.y": 1.2}, 0.45, {ease: FlxEase.sineOut});
		setExtrasVisible(true);
	}

	function setExtrasVisible(value:Bool)
	{
		for (text in scrollingTexts) text.visible = value;
		glow.visible = glowDark.visible = value;
	}

	public function confirm():Void
	{
		FlxTween.color(pinkBack, 0.33, 0xFFFFD0D5, 0xFF171831, {ease: FlxEase.quadOut});
		orangeBackShit.visible = alsoOrangeLOL.visible = false;
		confirmGlow.visible = confirmGlow2.visible = true;
		backingTextYeah.anim.play('', true);
		confirmGlow2.alpha = 0;
		confirmGlow.alpha = 0;
		setExtrasVisible(false);

		FlxTween.color(instance.backingImage, 0.5, 0xFFA8A8A8, 0xFF646464, {onUpdate: function(_) instance.syncAngleMask()});
		FlxTween.tween(confirmGlow2, {alpha: 0.5}, 0.33, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				confirmGlow2.alpha = 0.6;
				confirmGlow.alpha = 1;
				confirmTextGlow.visible = true;
				confirmTextGlow.alpha = 1;
				FlxTween.tween(confirmTextGlow, {alpha: 0.4}, 0.5);
				FlxTween.tween(confirmGlow, {alpha: 0}, 0.5);
				FlxTween.color(instance.backingImage, 2, 0xFFCDCDCD, 0xFF555555, {ease: FlxEase.expoOut, onUpdate: function(_) instance.syncAngleMask()});
			}
		});
	}

	public function beatHit(beat:Int):Void
	{
		var beatFreq:Int = beatFreqList[Std.int(FlxMath.bound(Math.floor(Conductor.bpm / 140), 0, beatFreqList.length - 1))];
		if (beat % beatFreq != 0 || !glow.visible) return;
		FlxTween.cancelTweensOf(glow);
		FlxTween.cancelTweensOf(glowDark);
		glow.alpha = 0.8;
		FlxTween.tween(glow, {alpha: 0}, 16 / 24, {ease: FlxEase.quartOut});
		glowDark.alpha = 0;
		FlxTween.tween(glowDark, {alpha: 0.6}, 18 / 24, {ease: FlxEase.quartOut});
	}

	public function disappear():Void
	{
		FlxTween.color(pinkBack, 0.25, 0xFFFFD863, 0xFFFFD0D5, {ease: FlxEase.quadOut});
		cardGlow.visible = true;
		cardGlow.alpha = 1;
		cardGlow.scale.set(1, 1);
		FlxTween.tween(cardGlow, {alpha: 0, "scale.x": 1.2, "scale.y": 1.2}, 0.25, {ease: FlxEase.sineOut});
		orangeBackShit.visible = alsoOrangeLOL.visible = false;
		setExtrasVisible(false);
	}
}
