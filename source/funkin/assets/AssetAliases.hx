package funkin.assets;

class AssetAliases
{
	public static final RENAMED:Map<String, String> = [
		'images/BBBump.png' => 'images/title/BBBump.png',
		'images/BBBump.xml' => 'images/title/BBBump.xml',
		'images/Menu_Tracks.png' => 'images/menus/Menu_Tracks.png',
		'images/PessyBump.png' => 'images/title/PessyBump.png',
		'images/PessyBump.xml' => 'images/title/PessyBump.xml',
		'images/ShadowBump.png' => 'images/title/ShadowBump.png',
		'images/ShadowBump.xml' => 'images/title/ShadowBump.xml',
		'images/ZRiverBump.png' => 'images/title/ZRiverBump.png',
		'images/ZRiverBump.xml' => 'images/title/ZRiverBump.xml',
		'images/alphabet.json' => 'images/ui/alphabet.json',
		'images/alphabet.png' => 'images/ui/alphabet.png',
		'images/alphabet.xml' => 'images/ui/alphabet.xml',
		'images/alphabet_playstation.png' => 'images/ui/alphabet_playstation.png',
		'images/alphabet_playstation.xml' => 'images/ui/alphabet_playstation.xml',
		'images/bad.png' => 'images/ui/bad.png',
		'images/campaign_menu_UI_assets.png' => 'images/menus/campaign_menu_UI_assets.png',
		'images/campaign_menu_UI_assets.xml' => 'images/menus/campaign_menu_UI_assets.xml',
		'images/checkboxanim.png' => 'images/menus/checkboxanim.png',
		'images/checkboxanim.xml' => 'images/menus/checkboxanim.xml',
		'images/combo.png' => 'images/ui/combo.png',
		'images/controllertype.png' => 'images/menus/controllertype.png',
		'images/funkay.png' => 'images/menus/funkay.png',
		'images/gfDanceTitle.json' => 'images/title/gfDanceTitle.json',
		'images/gfDanceTitle.png' => 'images/title/gfDanceTitle.png',
		'images/gfDanceTitle.xml' => 'images/title/gfDanceTitle.xml',
		'images/go.png' => 'images/ui/go.png',
		'images/good.png' => 'images/ui/good.png',
		'images/healthBar.png' => 'images/ui/healthBar.png',
		'images/logoBumpin.png' => 'images/title/logoBumpin.png',
		'images/logoBumpin.xml' => 'images/title/logoBumpin.xml',
		'images/menuBG.png' => 'images/menus/menuBG.png',
		'images/menuBGBlue.png' => 'images/menus/menuBGBlue.png',
		'images/menuBGMagenta.png' => 'images/menus/menuBGMagenta.png',
		'images/menuDesat.png' => 'images/menus/menuDesat.png',
		'images/modsMenuButtons.png' => 'images/menus/modsMenuButtons.png',
		'images/newgrounds_logo.png' => 'images/title/newgrounds_logo.png',
		'images/num0.png' => 'images/ui/num0.png',
		'images/num1.png' => 'images/ui/num1.png',
		'images/num2.png' => 'images/ui/num2.png',
		'images/num3.png' => 'images/ui/num3.png',
		'images/num4.png' => 'images/ui/num4.png',
		'images/num5.png' => 'images/ui/num5.png',
		'images/num6.png' => 'images/ui/num6.png',
		'images/num7.png' => 'images/ui/num7.png',
		'images/num8.png' => 'images/ui/num8.png',
		'images/num9.png' => 'images/ui/num9.png',
		'images/pt-BR/Menu_Tracks.png' => 'images/pt-BR/menus/Menu_Tracks.png',
		'images/ready.png' => 'images/ui/ready.png',
		'images/set.png' => 'images/ui/set.png',
		'images/shit.png' => 'images/ui/shit.png',
		'images/sick.png' => 'images/ui/sick.png',
		'images/speech_bubble.png' => 'images/dialogue/speech_bubble.png',
		'images/speech_bubble.xml' => 'images/dialogue/speech_bubble.xml',
		'images/timeBar.png' => 'images/ui/timeBar.png',
		'images/titleEnter.png' => 'images/title/titleEnter.png',
		'images/titleEnter.xml' => 'images/title/titleEnter.xml',
		'images/unknownMod.png' => 'images/menus/unknownMod.png'
	];

	static var reverse:Map<String, String>;

	public static function get(path:String):Null<String>
	{
		if (path == null) return null;
		if (RENAMED.exists(path)) return RENAMED.get(path);
		if (reverse == null)
		{
			reverse = new Map();
			for (oldPath => newPath in RENAMED) reverse.set(newPath, oldPath);
		}
		return reverse.get(path);
	}

	public static function add(oldPath:String, newPath:String)
	{
		RENAMED.set(oldPath, newPath);
		if (reverse != null) reverse.set(newPath, oldPath);
	}
}
