package funkin.mobile.screen;

class ScreenStyle
{
	public static inline final ORIGINAL:String = funkin.graphics.ScreenFit.ORIGINAL;
	public static inline final FULL:String = funkin.graphics.ScreenFit.FULL;

	public static function apply()
	{
		funkin.graphics.ScreenFit.apply();
	}
}
