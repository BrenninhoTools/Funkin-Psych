#include "funkin_discord.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__ANDROID__) || (defined(__APPLE__) && TARGET_OS_IPHONE)
#define FUNKIN_DISCORD_MOBILE 1
#endif

#if !defined(FUNKIN_DISCORD_MOBILE)
#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>
#endif
#endif

namespace funkin_discord
{
	namespace
	{
		enum Opcode : uint32_t
		{
			OP_HANDSHAKE = 0,
			OP_FRAME = 1,
			OP_CLOSE = 2,
			OP_PING = 3,
			OP_PONG = 4
		};

		struct Button
		{
			std::string label;
			std::string url;
		};

		struct Activity
		{
			int type = 0;
			std::string details;
			std::string state;
			std::string largeImage;
			std::string largeText;
			std::string smallImage;
			std::string smallText;
			double start = 0;
			double end = 0;
			std::string partyId;
			int partySize = 0;
			int partyMax = 0;
			Button buttons[2];
			bool cleared = true;
		};

		std::string escape(const std::string &value)
		{
			std::string out;
			out.reserve(value.size() + 8);
			for (unsigned char c : value)
			{
				switch (c)
				{
					case '"': out += "\\\""; break;
					case '\\': out += "\\\\"; break;
					case '\n': out += "\\n"; break;
					case '\r': out += "\\r"; break;
					case '\t': out += "\\t"; break;
					default:
						if (c < 0x20)
						{
							char buffer[8];
							std::snprintf(buffer, sizeof(buffer), "\\u%04x", c);
							out += buffer;
						}
						else out += static_cast<char>(c);
				}
			}
			return out;
		}

		std::string clip(const char *value, size_t limit)
		{
			if (value == nullptr) return std::string();
			std::string text(value);
			if (text.size() <= limit) return text;
			size_t cut = limit;
			while (cut > 0 && (static_cast<unsigned char>(text[cut]) & 0xC0) == 0x80) cut--;
			return text.substr(0, cut);
		}

		void field(std::string &json, bool &first, const char *key, const std::string &value)
		{
			if (value.empty()) return;
			if (!first) json += ',';
			first = false;
			json += '"';
			json += key;
			json += "\":\"";
			json += escape(value);
			json += '"';
		}

		std::string extract(const std::string &json, const char *key, size_t from)
		{
			std::string needle = std::string("\"") + key + "\":";
			size_t at = json.find(needle, from);
			if (at == std::string::npos) return std::string();
			at += needle.size();
			while (at < json.size() && (json[at] == ' ')) at++;
			if (at >= json.size() || json[at] != '"') return std::string();
			at++;
			std::string out;
			while (at < json.size() && json[at] != '"')
			{
				if (json[at] == '\\' && at + 1 < json.size())
				{
					at++;
					char c = json[at];
					out += c == 'n' ? '\n' : c;
				}
				else out += json[at];
				at++;
			}
			return out;
		}

		int extractInt(const std::string &json, const char *key)
		{
			std::string needle = std::string("\"") + key + "\":";
			size_t at = json.find(needle);
			if (at == std::string::npos) return 0;
			return std::atoi(json.c_str() + at + needle.size());
		}

		long long processId()
		{
#if defined(FUNKIN_DISCORD_MOBILE)
			return 0;
#elif defined(_WIN32)
			return static_cast<long long>(GetCurrentProcessId());
#else
			return static_cast<long long>(getpid());
#endif
		}

		class Pipe
		{
		public:
			~Pipe()
			{
				close();
			}

			bool open()
			{
#if defined(FUNKIN_DISCORD_MOBILE)
				return false;
#elif defined(_WIN32)
				for (int i = 0; i < 10; i++)
				{
					wchar_t name[64];
					std::swprintf(name, 64, L"\\\\.\\pipe\\discord-ipc-%d", i);
					HANDLE handle = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
					if (handle != INVALID_HANDLE_VALUE)
					{
						pipe = handle;
						return true;
					}
					if (GetLastError() == ERROR_PIPE_BUSY && WaitNamedPipeW(name, 1000))
					{
						handle = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
						if (handle != INVALID_HANDLE_VALUE)
						{
							pipe = handle;
							return true;
						}
					}
				}
				return false;
#else
				const char *bases[] = {std::getenv("XDG_RUNTIME_DIR"), std::getenv("TMPDIR"), std::getenv("TMP"), std::getenv("TEMP"), "/tmp"};
				const char *prefixes[] = {"", "app/com.discordapp.Discord/", "app/com.discordapp.DiscordCanary/", "snap.discord/", "snap.discord-canary/", ".flatpak/dev.vencord.Vesktop/xdg-run/"};
				for (const char *base : bases)
				{
					if (base == nullptr || base[0] == 0) continue;
					for (const char *prefix : prefixes)
					{
						for (int i = 0; i < 10; i++)
						{
							std::string path = std::string(base);
							if (path.back() != '/') path += '/';
							path += prefix;
							path += "discord-ipc-" + std::to_string(i);
							if (path.size() >= sizeof(sockaddr_un::sun_path)) continue;
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
							::close(fd);
						}
					}
				}
				return false;
#endif
			}

			void close()
			{
#if defined(FUNKIN_DISCORD_MOBILE)
#elif defined(_WIN32)
				if (pipe != INVALID_HANDLE_VALUE) CloseHandle(pipe);
				pipe = INVALID_HANDLE_VALUE;
#else
				if (socketFd >= 0) ::close(socketFd);
				socketFd = -1;
#endif
				buffer.clear();
			}

			bool isOpen() const
			{
#if defined(FUNKIN_DISCORD_MOBILE)
				return false;
#elif defined(_WIN32)
				return pipe != INVALID_HANDLE_VALUE;
#else
				return socketFd >= 0;
#endif
			}

			bool write(uint32_t opcode, const std::string &payload)
			{
				if (!isOpen()) return false;
				std::string frame;
				frame.resize(8 + payload.size());
				uint32_t length = static_cast<uint32_t>(payload.size());
				for (int i = 0; i < 4; i++)
				{
					frame[i] = static_cast<char>((opcode >> (8 * i)) & 0xFF);
					frame[4 + i] = static_cast<char>((length >> (8 * i)) & 0xFF);
				}
				std::memcpy(&frame[8], payload.data(), payload.size());
				return writeRaw(frame.data(), frame.size());
			}

			bool read(uint32_t &opcode, std::string &payload, int timeoutMs)
			{
				if (!isOpen()) return false;
				auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeoutMs);
				while (true)
				{
					if (buffer.size() >= 8)
					{
						uint32_t op = 0;
						uint32_t length = 0;
						for (int i = 0; i < 4; i++)
						{
							op |= static_cast<uint32_t>(static_cast<unsigned char>(buffer[i])) << (8 * i);
							length |= static_cast<uint32_t>(static_cast<unsigned char>(buffer[4 + i])) << (8 * i);
						}
						if (length > 64 * 1024)
						{
							close();
							return false;
						}
						if (buffer.size() >= 8 + length)
						{
							opcode = op;
							payload.assign(buffer.data() + 8, length);
							buffer.erase(0, 8 + length);
							return true;
						}
					}
					int received = readAvailable();
					if (received < 0) return false;
					if (received == 0)
					{
						if (std::chrono::steady_clock::now() >= deadline) return false;
						std::this_thread::sleep_for(std::chrono::milliseconds(5));
					}
				}
			}

			bool failed = false;

		private:
#if defined(_WIN32) && !defined(FUNKIN_DISCORD_MOBILE)
			HANDLE pipe = INVALID_HANDLE_VALUE;
#else
			int socketFd = -1;
#endif
			std::string buffer;

			bool writeRaw(const char *data, size_t size)
			{
#if defined(FUNKIN_DISCORD_MOBILE)
				(void)data;
				(void)size;
				return false;
#elif defined(_WIN32)
				DWORD written = 0;
				while (size > 0)
				{
					if (!WriteFile(pipe, data, static_cast<DWORD>(size), &written, nullptr))
					{
						close();
						return false;
					}
					data += written;
					size -= written;
				}
				return true;
#else
				while (size > 0)
				{
#if defined(MSG_NOSIGNAL)
					ssize_t sent = send(socketFd, data, size, MSG_NOSIGNAL);
#else
					ssize_t sent = send(socketFd, data, size, 0);
#endif
					if (sent < 0)
					{
						if (errno == EINTR) continue;
						close();
						return false;
					}
					data += sent;
					size -= static_cast<size_t>(sent);
				}
				return true;
#endif
			}

			int readAvailable()
			{
				char chunk[4096];
#if defined(FUNKIN_DISCORD_MOBILE)
				(void)chunk;
				return -1;
#elif defined(_WIN32)
				DWORD available = 0;
				if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr))
				{
					close();
					return -1;
				}
				if (available == 0) return 0;
				DWORD toRead = available < sizeof(chunk) ? available : static_cast<DWORD>(sizeof(chunk));
				DWORD got = 0;
				if (!ReadFile(pipe, chunk, toRead, &got, nullptr))
				{
					close();
					return -1;
				}
				buffer.append(chunk, got);
				return static_cast<int>(got);
#else
				pollfd descriptor;
				descriptor.fd = socketFd;
				descriptor.events = POLLIN;
				descriptor.revents = 0;
				int ready = poll(&descriptor, 1, 0);
				if (ready <= 0) return ready < 0 && errno != EINTR ? (close(), -1) : 0;
				if (descriptor.revents & (POLLERR | POLLHUP | POLLNVAL))
				{
					if (!(descriptor.revents & POLLIN))
					{
						close();
						return -1;
					}
				}
				ssize_t got = recv(socketFd, chunk, sizeof(chunk), 0);
				if (got <= 0)
				{
					if (got < 0 && (errno == EAGAIN || errno == EINTR)) return 0;
					close();
					return -1;
				}
				buffer.append(chunk, static_cast<size_t>(got));
				return static_cast<int>(got);
#endif
			}
		};

		struct State
		{
			std::mutex mutex;
			std::condition_variable wake;
			std::thread worker;
			std::atomic<bool> running{false};
			std::atomic<int> status{STATUS_DISCONNECTED};
			std::string clientId;
			Activity pending;
			Activity staged;
			bool dirty = false;
			std::deque<int> events;
			std::string userId;
			std::string userName;
			std::string globalName;
			std::string avatar;
			std::string error;
			int errorCode = 0;
			uint64_t nonce = 0;
		};

		State &state()
		{
			static State instance;
			return instance;
		}

		void pushEvent(State &s, int event)
		{
			if (s.events.size() > 32) s.events.pop_front();
			s.events.push_back(event);
		}

		std::string activityJson(const Activity &activity, uint64_t nonce)
		{
			std::string json = "{\"cmd\":\"SET_ACTIVITY\",\"args\":{\"pid\":" + std::to_string(processId());
			if (activity.cleared)
			{
				json += ",\"activity\":null}";
			}
			else
			{
				json += ",\"activity\":{\"type\":" + std::to_string(activity.type);
				bool first = false;
				field(json, first, "details", activity.details);
				field(json, first, "state", activity.state);
				if (activity.start > 0 || activity.end > 0)
				{
					json += ",\"timestamps\":{";
					bool inner = true;
					if (activity.start > 0)
					{
						json += "\"start\":" + std::to_string(static_cast<long long>(activity.start));
						inner = false;
					}
					if (activity.end > 0)
					{
						if (!inner) json += ',';
						json += "\"end\":" + std::to_string(static_cast<long long>(activity.end));
					}
					json += '}';
				}
				if (!activity.largeImage.empty() || !activity.smallImage.empty())
				{
					json += ",\"assets\":{";
					bool inner = true;
					field(json, inner, "large_image", activity.largeImage);
					field(json, inner, "large_text", activity.largeText);
					field(json, inner, "small_image", activity.smallImage);
					field(json, inner, "small_text", activity.smallText);
					json += '}';
				}
				if (!activity.partyId.empty() || activity.partyMax > 0)
				{
					json += ",\"party\":{";
					bool inner = true;
					field(json, inner, "id", activity.partyId);
					if (activity.partyMax > 0)
					{
						if (!inner) json += ',';
						json += "\"size\":[" + std::to_string(activity.partySize) + "," + std::to_string(activity.partyMax) + "]";
					}
					json += '}';
				}
				bool hasButtons = false;
				for (const Button &button : activity.buttons)
				{
					if (button.label.empty() || button.url.empty()) continue;
					json += hasButtons ? "," : ",\"buttons\":[";
					json += "{\"label\":\"" + escape(button.label) + "\",\"url\":\"" + escape(button.url) + "\"}";
					hasButtons = true;
				}
				if (hasButtons) json += ']';
				json += "}}";
			}
			json += ",\"nonce\":\"" + std::to_string(nonce) + "\"}";
			return json;
		}

		bool handshake(Pipe &pipe, State &s, const std::string &clientId)
		{
			std::string payload = "{\"v\":1,\"client_id\":\"" + escape(clientId) + "\"}";
			if (!pipe.write(OP_HANDSHAKE, payload)) return false;
			uint32_t opcode = 0;
			std::string response;
			if (!pipe.read(opcode, response, 5000)) return false;
			if (opcode == OP_CLOSE)
			{
				std::lock_guard<std::mutex> lock(s.mutex);
				s.error = extract(response, "message", 0);
				s.errorCode = extractInt(response, "code");
				pushEvent(s, EVENT_ERROR);
				return false;
			}
			if (opcode != OP_FRAME || response.find("\"READY\"") == std::string::npos) return false;
			size_t user = response.find("\"user\"");
			if (user == std::string::npos) user = 0;
			std::lock_guard<std::mutex> lock(s.mutex);
			s.userId = extract(response, "id", user);
			s.userName = extract(response, "username", user);
			s.globalName = extract(response, "global_name", user);
			s.avatar = extract(response, "avatar", user);
			s.dirty = true;
			pushEvent(s, EVENT_READY);
			return true;
		}

		void run()
		{
			State &s = state();
			Pipe pipe;
			int backoff = 2;
			while (s.running)
			{
				if (!pipe.isOpen())
				{
					s.status = STATUS_CONNECTING;
					std::string clientId;
					{
						std::lock_guard<std::mutex> lock(s.mutex);
						clientId = s.clientId;
					}
					if (pipe.open() && handshake(pipe, s, clientId))
					{
						s.status = STATUS_CONNECTED;
						backoff = 2;
					}
					else
					{
						pipe.close();
						s.status = STATUS_DISCONNECTED;
						std::unique_lock<std::mutex> lock(s.mutex);
						s.wake.wait_for(lock, std::chrono::seconds(backoff), [&] { return !s.running; });
						backoff = backoff < 30 ? backoff * 2 : 30;
						continue;
					}
				}

				Activity toSend;
				bool send = false;
				uint64_t nonce = 0;
				{
					std::lock_guard<std::mutex> lock(s.mutex);
					if (s.dirty)
					{
						toSend = s.pending;
						s.dirty = false;
						send = true;
						nonce = ++s.nonce;
					}
				}
				if (send && !pipe.write(OP_FRAME, activityJson(toSend, nonce)))
				{
					std::lock_guard<std::mutex> lock(s.mutex);
					s.dirty = true;
				}

				uint32_t opcode = 0;
				std::string payload;
				while (pipe.isOpen() && pipe.read(opcode, payload, 0))
				{
					if (opcode == OP_PING) pipe.write(OP_PONG, payload);
					else if (opcode == OP_CLOSE)
					{
						std::lock_guard<std::mutex> lock(s.mutex);
						s.error = extract(payload, "message", 0);
						s.errorCode = extractInt(payload, "code");
						pipe.close();
					}
					else if (opcode == OP_FRAME && payload.find("\"evt\":\"ERROR\"") != std::string::npos)
					{
						std::lock_guard<std::mutex> lock(s.mutex);
						s.error = extract(payload, "message", 0);
						s.errorCode = extractInt(payload, "code");
						pushEvent(s, EVENT_ERROR);
					}
				}

				if (!pipe.isOpen())
				{
					s.status = STATUS_DISCONNECTED;
					std::lock_guard<std::mutex> lock(s.mutex);
					s.dirty = true;
					pushEvent(s, EVENT_DISCONNECTED);
					continue;
				}

				std::unique_lock<std::mutex> lock(s.mutex);
				s.wake.wait_for(lock, std::chrono::milliseconds(250), [&] { return !s.running || s.dirty; });
			}
			if (pipe.isOpen())
			{
				Activity empty;
				pipe.write(OP_FRAME, activityJson(empty, ++s.nonce));
			}
			pipe.close();
			s.status = STATUS_DISCONNECTED;
		}

		thread_local std::string returned;

		const char *give(const std::string &value)
		{
			returned = value;
			return returned.c_str();
		}
	}

	bool supported()
	{
#if defined(FUNKIN_DISCORD_MOBILE)
		return false;
#else
		return true;
#endif
	}

	void start(const char *clientId)
	{
		State &s = state();
		if (!supported())
		{
			s.status = STATUS_UNSUPPORTED;
			return;
		}
		stop();
		{
			std::lock_guard<std::mutex> lock(s.mutex);
			s.clientId = clientId != nullptr ? clientId : "";
			s.events.clear();
			s.dirty = true;
		}
		s.running = true;
		s.worker = std::thread(run);
	}

	void stop()
	{
		State &s = state();
		if (!s.running && !s.worker.joinable()) return;
		s.running = false;
		s.wake.notify_all();
		if (s.worker.joinable()) s.worker.join();
		s.status = supported() ? STATUS_DISCONNECTED : STATUS_UNSUPPORTED;
	}

	int status()
	{
		return supported() ? state().status.load() : STATUS_UNSUPPORTED;
	}

	int pollEvent()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		if (s.events.empty()) return EVENT_NONE;
		int event = s.events.front();
		s.events.pop_front();
		return event;
	}

	void setActivity(int type, const char *details, const char *state_, const char *largeImage, const char *largeText, const char *smallImage,
		const char *smallText, double startTimestamp, double endTimestamp)
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		Activity &a = s.staged;
		a.type = type;
		a.details = clip(details, 128);
		a.state = clip(state_, 128);
		a.largeImage = clip(largeImage, 256);
		a.largeText = clip(largeText, 128);
		a.smallImage = clip(smallImage, 256);
		a.smallText = clip(smallText, 128);
		a.start = startTimestamp;
		a.end = endTimestamp;
		a.cleared = false;
	}

	void setParty(const char *id, int size, int max)
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		s.staged.partyId = clip(id, 128);
		s.staged.partySize = size;
		s.staged.partyMax = max;
	}

	void setButton(int index, const char *label, const char *url)
	{
		if (index < 0 || index > 1) return;
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		s.staged.buttons[index].label = clip(label, 32);
		s.staged.buttons[index].url = clip(url, 512);
	}

	void clearButtons()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		for (Button &button : s.staged.buttons) button = Button();
	}

	void commit()
	{
		State &s = state();
		{
			std::lock_guard<std::mutex> lock(s.mutex);
			s.pending = s.staged;
			s.dirty = true;
		}
		s.wake.notify_all();
	}

	void clearActivity()
	{
		State &s = state();
		{
			std::lock_guard<std::mutex> lock(s.mutex);
			s.staged = Activity();
			s.pending = Activity();
			s.dirty = true;
		}
		s.wake.notify_all();
	}

	const char *userId()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return give(s.userId);
	}

	const char *userName()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return give(s.userName);
	}

	const char *globalName()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return give(s.globalName);
	}

	const char *avatar()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return give(s.avatar);
	}

	const char *lastError()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return give(s.error);
	}

	int lastErrorCode()
	{
		State &s = state();
		std::lock_guard<std::mutex> lock(s.mutex);
		return s.errorCode;
	}
}
