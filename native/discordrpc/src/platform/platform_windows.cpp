#if defined(_WIN32)

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <cwchar>

#include "platform.h"

namespace funkin_discord
{
	namespace platform
	{
		namespace
		{
			SRWLOCK mutex = SRWLOCK_INIT;
			HANDLE wakeEvent = NULL;
			HANDLE thread = NULL;
			HANDLE pipe = INVALID_HANDLE_VALUE;
			void (*threadEntry)() = NULL;

			HANDLE event()
			{
				if (wakeEvent == NULL)
				{
					HANDLE created = CreateEventW(NULL, FALSE, FALSE, NULL);
					if (InterlockedCompareExchangePointer(&wakeEvent, created, NULL) != NULL) CloseHandle(created);
				}
				return wakeEvent;
			}

			DWORD WINAPI threadMain(LPVOID)
			{
				if (threadEntry != NULL) threadEntry();
				return 0;
			}

			HANDLE connectPipe(const wchar_t *name)
			{
				HANDLE handle = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
				if (handle != INVALID_HANDLE_VALUE) return handle;
				if (GetLastError() != ERROR_PIPE_BUSY || !WaitNamedPipeW(name, 1000)) return INVALID_HANDLE_VALUE;
				return CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
			}
		}

		bool supported()
		{
			return true;
		}

		const char *name()
		{
			return "windows";
		}

		long long processId()
		{
			return static_cast<long long>(GetCurrentProcessId());
		}

		void lock()
		{
			AcquireSRWLockExclusive(&mutex);
		}

		void unlock()
		{
			ReleaseSRWLockExclusive(&mutex);
		}

		void notify()
		{
			SetEvent(event());
		}

		void wait(int milliseconds)
		{
			WaitForSingleObject(event(), milliseconds < 0 ? 0 : static_cast<DWORD>(milliseconds));
		}

		void sleep(int milliseconds)
		{
			Sleep(milliseconds < 0 ? 0 : static_cast<DWORD>(milliseconds));
		}

		bool startThread(void (*entry)())
		{
			if (thread != NULL) return false;
			event();
			threadEntry = entry;
			thread = CreateThread(NULL, 64 * 1024, threadMain, NULL, STACK_SIZE_PARAM_IS_A_RESERVATION, NULL);
			if (thread == NULL) return false;
			SetThreadPriority(thread, THREAD_PRIORITY_BELOW_NORMAL);
			return true;
		}

		void joinThread()
		{
			if (thread == NULL) return;
			WaitForSingleObject(thread, INFINITE);
			CloseHandle(thread);
			thread = NULL;
		}

		bool pipeOpen()
		{
			pipeClose();
			for (int i = 0; i < 10; i++)
			{
				wchar_t pipeName[64];
				swprintf(pipeName, 64, L"\\\\.\\pipe\\discord-ipc-%d", i);
				HANDLE handle = connectPipe(pipeName);
				if (handle != INVALID_HANDLE_VALUE)
				{
					DWORD mode = PIPE_READMODE_BYTE;
					SetNamedPipeHandleState(handle, &mode, NULL, NULL);
					pipe = handle;
					return true;
				}
			}
			return false;
		}

		void pipeClose()
		{
			if (pipe != INVALID_HANDLE_VALUE) CloseHandle(pipe);
			pipe = INVALID_HANDLE_VALUE;
		}

		bool pipeIsOpen()
		{
			return pipe != INVALID_HANDLE_VALUE;
		}

		bool pipeWrite(const char *data, size_t size)
		{
			while (size > 0 && pipe != INVALID_HANDLE_VALUE)
			{
				DWORD written = 0;
				DWORD chunk = size > 0x10000 ? 0x10000 : static_cast<DWORD>(size);
				if (!WriteFile(pipe, data, chunk, &written, NULL) || written == 0)
				{
					pipeClose();
					return false;
				}
				data += written;
				size -= written;
			}
			return size == 0;
		}

		int pipeRead(char *buffer, size_t size)
		{
			if (pipe == INVALID_HANDLE_VALUE) return -1;
			DWORD available = 0;
			if (!PeekNamedPipe(pipe, NULL, 0, NULL, &available, NULL))
			{
				pipeClose();
				return -1;
			}
			if (available == 0) return 0;
			DWORD toRead = available < size ? available : static_cast<DWORD>(size);
			DWORD got = 0;
			if (!ReadFile(pipe, buffer, toRead, &got, NULL))
			{
				pipeClose();
				return -1;
			}
			return static_cast<int>(got);
		}
	}
}

#endif
