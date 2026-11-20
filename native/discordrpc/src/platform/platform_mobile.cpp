#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__ANDROID__) || (defined(__APPLE__) && TARGET_OS_IPHONE)

#include "platform.h"

namespace funkin_discord
{
	namespace platform
	{
		bool supported()
		{
			return false;
		}

		const char *name()
		{
#if defined(__ANDROID__)
			return "android";
#else
			return "ios";
#endif
		}

		long long processId()
		{
			return 0;
		}

		void lock() {}

		void unlock() {}

		void notify() {}

		void wait(int) {}

		void sleep(int) {}

		bool startThread(void (*)())
		{
			return false;
		}

		void joinThread() {}

		bool pipeOpen()
		{
			return false;
		}

		void pipeClose() {}

		bool pipeIsOpen()
		{
			return false;
		}

		bool pipeWrite(const char *, size_t)
		{
			return false;
		}

		int pipeRead(char *, size_t)
		{
			return -1;
		}
	}
}

#endif
