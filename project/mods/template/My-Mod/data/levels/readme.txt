Put your level .json files here! (levels used to be called weeks)

You can create one with the Level Editor in the editors menu (press 7 in the main menu).
The order of the levels can be set in levelList.txt, one file name per line.
Old week files in data/weeks/ or weeks/ still load.

{
	"version": "2.0.0",
	"name": "Week 1",
	"title": "Daddy Dearest",
	"background": "stage",
	"characters": {"opponent": "dad", "player": "bf", "girlfriend": "gf"},
	"songs": [
		{"name": "Bopeebo", "icon": "dad", "color": "#9271FD"},
		{"name": "Fresh", "icon": "dad", "color": "#9271FD"}
	],
	"difficulties": ["Easy", "Normal", "Hard"],
	"unlock": {"locked": false, "hidden": false, "after": "tutorial"},
	"visibility": {"storyMode": true, "freeplay": true}
}

name is shown in the Reset Score menu and freeplay, title is shown in the story menu.
The level menu image goes in images/storymenu/<file name>.png.
