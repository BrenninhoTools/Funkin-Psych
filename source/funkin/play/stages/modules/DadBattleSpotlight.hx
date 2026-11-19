package funkin.play.stages.modules;

import funkin.data.DataUtil;
import funkin.play.character.Character;
import funkin.play.notes.Note.EventNote;
import funkin.play.stages.objects.DadBattleFog;

class DadBattleSpotlight extends BaseStage
{
	var options:Dynamic;
	var eventName:String = 'Dadbattle Spotlight';
	var black:FlxSprite;
	var light:FlxSprite;
	var fog:DadBattleFog;
	var zoomAdd:Float = 0.12;

	override function create()
	{
		options = StageModules.consumeOptions();
		if (options.event != null) eventName = Std.string(options.event);
		zoomAdd = DataUtil.toFloat(options.zoom, 0.12);
	}

	override function eventPushed(event:EventNote)
	{
		if (event.event != eventName || black != null) return;

		black = new FlxSprite(-800, -400).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		black.scrollFactor.set();
		black.alpha = 0.25;
		black.visible = false;
		add(black);

		light = new FlxSprite(400, -400).loadGraphic(Paths.image(options.image != null ? Std.string(options.image) : 'spotlight'));
		light.antialiasing = Save.data.antialiasing;
		light.alpha = 0.375;
		light.blend = ADD;
		light.visible = false;
		add(light);

		fog = new DadBattleFog();
		fog.visible = false;
		add(fog);
	}

	override function eventCalled(name:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (name != eventName || black == null) return;
		var val:Int = Math.round(flValue1 != null ? flValue1 : 0);
		switch (val)
		{
			case 1, 2, 3:
				if (val == 1)
				{
					black.visible = true;
					light.visible = true;
					fog.visible = true;
					defaultCamZoom += zoomAdd;
				}
				var who:Character = val > 2 ? boyfriend : dad;
				light.alpha = 0;
				new FlxTimer().start(0.12, (_) -> light.alpha = 0.375);
				light.setPosition(who.getGraphicMidpoint().x - light.width / 2, who.y + who.height - light.height + 50);
				FlxTween.tween(fog, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
			default:
				black.visible = false;
				light.visible = false;
				defaultCamZoom -= zoomAdd;
				FlxTween.tween(fog, {alpha: 0}, 0.7, {onComplete: (_) -> fog.visible = false});
		}
	}
}
