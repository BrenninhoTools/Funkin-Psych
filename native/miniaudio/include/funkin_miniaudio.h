#pragma once

namespace funkin_miniaudio
{
	const char* version();

	bool engineInit();
	void engineShutdown();
	bool engineReady();
	void setMasterVolume(float volume);
	float getMasterVolume();
	int engineSampleRate();
	int engineChannels();

	int soundLoadFile(const char* path, bool stream);
	int soundLoadMemory(const unsigned char* data, int size);
	void soundRelease(int id);
	bool soundPlay(int id);
	bool soundStop(int id);
	bool soundIsPlaying(int id);
	void soundSetVolume(int id, float volume);
	float soundGetVolume(int id);
	void soundSetPan(int id, float pan);
	void soundSetPitch(int id, float pitch);
	void soundSetLooping(int id, bool looping);
	bool soundIsLooping(int id);
	bool soundAtEnd(int id);
	void soundSeek(int id, double milliseconds);
	double soundGetTime(int id);
	double soundGetLength(int id);
	float soundGetPeak(int id);

	float bufferPeak(const unsigned char* data, int byteLength, int bitsPerSample, int channels, int startFrame, int frameCount, int channel);
}
