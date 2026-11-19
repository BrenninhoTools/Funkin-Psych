Put compiled .cppia scripts here. They are loaded when the mod is enabled and stay active in every state.

.cppia files placed in scripts/ or data/songs/your-song/ are loaded only while that song is playing.

The class with the same name as the file is created automatically. If it extends funkin.scripting.cppia.CppiaScript
you get access to game, add, insert, remove, getVar and setVar. Any method named like a PlayState callback
(onCreate, onCreatePost, onUpdate, onBeatHit, onStepHit, goodNoteHit, onDestroy...) is called by the game.

See docs/CPPIA.md in the engine source for how to compile them.
