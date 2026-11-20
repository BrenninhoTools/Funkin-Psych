#if !defined(_WIN32)

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if !defined(__ANDROID__) && !(defined(__APPLE__) && TARGET_OS_IPHONE)

#include <errno.h>
#include <poll.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#include <cstdlib>
#include <cstring>
#include <string>

#include "platform.h"

namespace funkin_discord
{
	namespace platform
	{
		namespace
		{
			pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
			pthread_mutex_t wakeMutex = PTHREAD_MUTEX_INITIALIZER;
			pthread_cond_t wakeCondition = PTHREAD_COND_INITIALIZER;
			bool woken = false;
			pthread_t thread;
			bool threadRunning = false;
			int socketFd = -1;
			void (*threadEntry)() = nullptr;

			void *threadMain(void *)
			{
				if (threadEntry != nullptr) threadEntry();
				return nullptr;
			}

			bool tryConnect(const std::string &path)
			{
				if (path.size() >= sizeof(sockaddr_un::sun_path)) return false;
				int fd = socket(AF_UNIX, SOCK_STREAM, 0);
				if (fd < 0) return false;
#if defined(SO_NOSIGPIPE)
				int one = 1;
				setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
				sockaddr_un address;
				std::memset(&address, 0, sizeof(address));
				address.sun_family = AF_UNIX;
				std::strncpy(address.sun_path, path.c_str(), sizeof(address.sun_path) - 1);
				if (connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) == 0)
				{
					socketFd = fd;
					return true;
				}
				close(fd);
				return false;
			}
		}

		bool supported()
		{
			return true;
		}

		const char *name()
		{
#if defined(__APPLE__)
			return "macos";
#else
			return "linux";
#endif
		}

		long long processId()
		{
			return static_cast<long long>(getpid());
		}

		void lock()
		{
			pthread_mutex_lock(&mutex);
		}

		void unlock()
		{
			pthread_mutex_unlock(&mutex);
		}

		void notify()
		{
			pthread_mutex_lock(&wakeMutex);
			woken = true;
			pthread_cond_signal(&wakeCondition);
			pthread_mutex_unlock(&wakeMutex);
		}

		void wait(int milliseconds)
		{
			timeval now;
			gettimeofday(&now, nullptr);
			long long nanos = static_cast<long long>(now.tv_usec) * 1000 + static_cast<long long>(milliseconds) * 1000000LL;
			timespec deadline;
			deadline.tv_sec = now.tv_sec + static_cast<time_t>(nanos / 1000000000LL);
			deadline.tv_nsec = static_cast<long>(nanos % 1000000000LL);
			pthread_mutex_lock(&wakeMutex);
			while (!woken)
			{
				if (pthread_cond_timedwait(&wakeCondition, &wakeMutex, &deadline) == ETIMEDOUT) break;
			}
			woken = false;
			pthread_mutex_unlock(&wakeMutex);
		}

		void sleep(int milliseconds)
		{
			usleep(static_cast<useconds_t>(milliseconds < 0 ? 0 : milliseconds) * 1000);
		}

		bool startThread(void (*entry)())
		{
			if (threadRunning) return false;
			threadEntry = entry;
			threadRunning = pthread_create(&thread, nullptr, threadMain, nullptr) == 0;
			return threadRunning;
		}

		void joinThread()
		{
			if (!threadRunning) return;
			pthread_join(thread, nullptr);
			threadRunning = false;
		}

		bool pipeOpen()
		{
			pipeClose();
			const char *bases[] = {std::getenv("XDG_RUNTIME_DIR"), std::getenv("TMPDIR"), std::getenv("TMP"), std::getenv("TEMP"), "/tmp"};
			const char *prefixes[] = {"", "app/com.discordapp.Discord/", "app/com.discordapp.DiscordCanary/", "snap.discord/", "snap.discord-canary/",
				".flatpak/dev.vencord.Vesktop/xdg-run/"};
			for (const char *base : bases)
			{
				if (base == nullptr || base[0] == 0) continue;
				std::string root(base);
				if (root.back() != '/') root += '/';
				for (const char *prefix : prefixes)
				{
					for (int i = 0; i < 10; i++)
					{
						if (tryConnect(root + prefix + "discord-ipc-" + std::to_string(i))) return true;
					}
				}
			}
			return false;
		}

		void pipeClose()
		{
			if (socketFd >= 0) close(socketFd);
			socketFd = -1;
		}

		bool pipeIsOpen()
		{
			return socketFd >= 0;
		}

		bool pipeWrite(const char *data, size_t size)
		{
			while (size > 0 && socketFd >= 0)
			{
#if defined(MSG_NOSIGNAL)
				ssize_t sent = send(socketFd, data, size, MSG_NOSIGNAL);
#else
				ssize_t sent = send(socketFd, data, size, 0);
#endif
				if (sent < 0)
				{
					if (errno == EINTR) continue;
					pipeClose();
					return false;
				}
				data += sent;
				size -= static_cast<size_t>(sent);
			}
			return size == 0;
		}

		int pipeRead(char *buffer, size_t size)
		{
			if (socketFd < 0) return -1;
			pollfd descriptor;
			descriptor.fd = socketFd;
			descriptor.events = POLLIN;
			descriptor.revents = 0;
			int ready = poll(&descriptor, 1, 0);
			if (ready < 0)
			{
				if (errno == EINTR) return 0;
				pipeClose();
				return -1;
			}
			if (ready == 0) return 0;
			if (!(descriptor.revents & POLLIN))
			{
				pipeClose();
				return -1;
			}
			ssize_t got = recv(socketFd, buffer, size, 0);
			if (got < 0 && (errno == EAGAIN || errno == EINTR)) return 0;
			if (got <= 0)
			{
				pipeClose();
				return -1;
			}
			return static_cast<int>(got);
		}
	}
}

#endif
#endif
