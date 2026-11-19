import flixel.text.FlxText;

function onCreatePost()
{
	var label = new FlxText(10, 10, 0, 'Hello from ${game.songName}', 16);
	label.cameras = [game.camOther];
	game.add(label);
}
