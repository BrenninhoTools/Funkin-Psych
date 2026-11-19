package funkin.play.stages;

import funkin.data.DataUtil;
import funkin.play.stages.objects.*;

class StagePrefabs
{
	public static final TYPES:Array<String> = ['phillyTrain', 'mallCrowd', 'backgroundGirls', 'backgroundDancer', 'dadBattleFog'];

	public static function create(type:String, data:Dynamic):FlxSprite
	{
		var x:Float = DataUtil.toFloat(data.x, 0);
		var y:Float = DataUtil.toFloat(data.y, 0);
		return switch (type)
		{
			case 'phillyTrain':
				new PhillyTrain(x, y, data.image != null ? Std.string(data.image) : 'philly/train', data.sound != null ? Std.string(data.sound) : 'train_passes');
			case 'mallCrowd':
				new MallCrowd(x, y, data.image != null ? Std.string(data.image) : 'christmas/bottomBop', data.idle != null ? Std.string(data.idle) : 'Bottom Level Boppers Idle', data.hey != null ? Std.string(data.hey) : 'Bottom Level Boppers HEY');
			case 'backgroundGirls':
				new BackgroundGirls(x, y);
			case 'backgroundDancer':
				new BackgroundDancer(x, y);
			case 'dadBattleFog':
				new DadBattleFog();
			default:
				null;
		}
	}
}
