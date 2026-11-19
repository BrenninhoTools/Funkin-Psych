Put your custom character .json files here!

You can create a custom character using the Character Editor by pressing 7 in the main menu.

Characters use the v2 format. Old Psych Engine and V-Slice character files still load and are converted when saved from the editor.

{
	"version": "2.0.0",
	"render": {
		"type": "auto",
		"image": "characters/BOYFRIEND",
		"scale": 1,
		"flipX": false,
		"antialiasing": true,
		"frameSize": [150, 150]
	},
	"position": [0, 350],
	"camera": [0, 0],
	"healthIcon": {"id": "bf", "color": "#31B0D1"},
	"singDuration": 4,
	"vocals": "",
	"animations": [
		{"name": "idle", "prefix": "BF idle dance", "fps": 24, "loop": false, "indices": [], "offset": [-5, 0]}
	]
}

render.type values:
auto          detects the format from the files next to the image
sparrow       image.png + image.xml
packer        image.png + image.txt
aseprite      image.png + image.json (Aseprite / TexturePacker JSON hash or array)
multisparrow  several sparrow sheets, "image": ["sheet1", "sheet2"]
grid          a plain image cut in cells of frameSize, animations use "indices" as frame numbers
image         a single static image
atlas         Adobe Animate texture atlas folder (Animation.json + spritemap)
