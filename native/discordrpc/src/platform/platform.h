#ifndef FUNKIN_DISCORD_PLATFORM_H
#define FUNKIN_DISCORD_PLATFORM_H

#include <cstddef>

namespace funkin_discord
{
	namespace platform
	{
		bool supported();
		const char *name();
		long long processId();

		void lock();
		void unlock();
		void notify();
		void wait(int milliseconds);
		void sleep(int milliseconds);

		bool startThread(void (*entry)());
		void joinThread();

		bool pipeOpen();
		void pipeClose();
		bool pipeIsOpen();
		bool pipeWrite(const char *data, size_t size);
		int pipeRead(char *buffer, size_t size);

		struct Guard
		{
			Guard()
			{
				lock();
			}

			~Guard()
			{
				unlock();
			}
		};
	}
}

#endif
