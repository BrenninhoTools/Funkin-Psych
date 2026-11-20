#ifndef FUNKIN_DISCORD_H
#define FUNKIN_DISCORD_H

namespace funkin_discord
{
	enum Status
	{
		STATUS_UNSUPPORTED = -1,
		STATUS_DISCONNECTED = 0,
		STATUS_CONNECTING = 1,
		STATUS_CONNECTED = 2
	};

	enum Event
	{
		EVENT_NONE = 0,
		EVENT_READY = 1,
		EVENT_DISCONNECTED = 2,
		EVENT_ERROR = 3
	};

	bool supported();
	void start(const char *clientId);
	void stop();
	int status();
	int pollEvent();

	void setActivity(int type, const char *details, const char *state, const char *largeImage, const char *largeText, const char *smallImage,
		const char *smallText, double startTimestamp, double endTimestamp);
	void setParty(const char *id, int size, int max);
	void setButton(int index, const char *label, const char *url);
	void clearButtons();
	void commit();
	void clearActivity();

	const char *userId();
	const char *userName();
	const char *globalName();
	const char *avatar();
	const char *lastError();
	int lastErrorCode();
}

#endif
