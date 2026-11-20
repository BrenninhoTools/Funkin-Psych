#include "funkin_discord.h"
#include "platform/platform.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace funkin_discord
{
	namespace
	{
		enum Opcode
		{
			OP_HANDSHAKE = 0,
			OP_FRAME = 1,
			OP_CLOSE = 2,
			OP_PING = 3,
			OP_PONG = 4
		};

		const int EVENT_CAPACITY = 32;
		const uint32_t MAX_FRAME = 64 * 1024;

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

		struct State
		{
			bool running = false;
			int status = STATUS_DISCONNECTED;
			std::string clientId;
			Activity pending;
			Activity staged;
			bool dirty = false;
			int events[EVENT_CAPACITY];
			int eventHead = 0;
			int eventCount = 0;
			std::string userId;
			std::string userName;
			std::string globalName;
			std::string avatar;
			std::string error;
			int errorCode = 0;
			uint64_t nonce = 0;
			std::string buffer;
		};

		State &state()
		{
			static State instance;
			return instance;
		}

		void pushEvent(State &s, int event)
		{
			if (s.eventCount == EVENT_CAPACITY)
			{
				s.eventHead = (s.eventHead + 1) % EVENT_CAPACITY;
				s.eventCount--;
			}
			s.events[(s.eventHead + s.eventCount) % EVENT_CAPACITY] = event;
			s.eventCount++;
		}

		void setStatus(int value)
		{
			platform::Guard guard;
			state().status = value;
		}

		bool isRunning()
		{
			platform::Guard guard;
			return state().running;
		}

		std::string escape(const std::string &value)
		{
			std::string out;
			out.reserve(value.size() + 8);
			for (size_t i = 0; i < value.size(); i++)
			{
				unsigned char c = static_cast<unsigned char>(value[i]);
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
							char code[8];
							std::snprintf(code, sizeof(code), "\\u%04x", c);
							out += code;
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
			while (at < json.size() && json[at] == ' ') at++;
			if (at >= json.size() || json[at] != '"') return std::string();
			at++;
			std::string out;
			while (at < json.size() && json[at] != '"')
			{
				if (json[at] == '\\' && at + 1 < json.size())
				{
					at++;
					out += json[at] == 'n' ? '\n' : json[at];
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

		std::string number(double value)
		{
			char text[32];
			std::snprintf(text, sizeof(text), "%lld", static_cast<long long>(value));
			return text;
		}

		std::string activityJson(const Activity &activity, uint64_t nonce)
		{
			std::string json = "{\"cmd\":\"SET_ACTIVITY\",\"args\":{\"pid\":" + number(static_cast<double>(platform::processId()));
			if (activity.cleared) json += ",\"activity\":null}";
			else
			{
				json += ",\"activity\":{\"type\":" + number(activity.type);
				bool first = false;
				field(json, first, "details", activity.details);
				field(json, first, "state", activity.state);
				if (activity.start > 0 || activity.end > 0)
				{
					json += ",\"timestamps\":{";
					if (activity.start > 0) json += "\"start\":" + number(activity.start);
					if (activity.end > 0) json += std::string(activity.start > 0 ? "," : "") + "\"end\":" + number(activity.end);
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
						json += "\"size\":[" + number(activity.partySize) + "," + number(activity.partyMax) + "]";
					}
					json += '}';
				}
				bool hasButtons = false;
				for (int i = 0; i < 2; i++)
				{
					const Button &button = activity.buttons[i];
					if (button.label.empty() || button.url.empty()) continue;
					json += hasButtons ? "," : ",\"buttons\":[";
					json += "{\"label\":\"" + escape(button.label) + "\",\"url\":\"" + escape(button.url) + "\"}";
					hasButtons = true;
				}
				if (hasButtons) json += ']';
				json += "}}";
			}
			json += ",\"nonce\":\"" + number(static_cast<double>(nonce)) + "\"}";
			return json;
		}

		bool writeFrame(uint32_t opcode, const std::string &payload)
		{
			std::string frame(8 + payload.size(), '\0');
			uint32_t length = static_cast<uint32_t>(payload.size());
			for (int i = 0; i < 4; i++)
			{
				frame[i] = static_cast<char>((opcode >> (8 * i)) & 0xFF);
				frame[4 + i] = static_cast<char>((length >> (8 * i)) & 0xFF);
			}
			if (!payload.empty()) std::memcpy(&frame[8], payload.data(), payload.size());
			return platform::pipeWrite(frame.data(), frame.size());
		}

		bool readFrame(std::string &buffer, uint32_t &opcode, std::string &payload, int timeoutMs)
		{
			int waited = 0;
			char chunk[4096];
			while (platform::pipeIsOpen())
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
					if (length > MAX_FRAME)
					{
						platform::pipeClose();
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
				int got = platform::pipeRead(chunk, sizeof(chunk));
				if (got < 0) return false;
				if (got > 0)
				{
					buffer.append(chunk, static_cast<size_t>(got));
					continue;
				}
				if (waited >= timeoutMs) return false;
				platform::sleep(5);
				waited += 5;
			}
			return false;
		}

		void recordError(const std::string &payload, bool notify)
		{
			State &s = state();
			platform::Guard guard;
			s.error = extract(payload, "message", 0);
			s.errorCode = extractInt(payload, "code");
			if (notify) pushEvent(s, EVENT_ERROR);
		}

		bool handshake(std::string &buffer)
		{
			State &s = state();
			std::string clientId;
			{
				platform::Guard guard;
				clientId = s.clientId;
			}
			if (!writeFrame(OP_HANDSHAKE, "{\"v\":1,\"client_id\":\"" + escape(clientId) + "\"}")) return false;
			uint32_t opcode = 0;
			std::string response;
			if (!readFrame(buffer, opcode, response, 5000)) return false;
			if (opcode == OP_CLOSE)
			{
				recordError(response, true);
				return false;
			}
			if (opcode != OP_FRAME || response.find("\"READY\"") == std::string::npos) return false;
			size_t user = response.find("\"user\"");
			if (user == std::string::npos) user = 0;
			platform::Guard guard;
			s.userId = extract(response, "id", user);
			s.userName = extract(response, "username", user);
			s.globalName = extract(response, "global_name", user);
			s.avatar = extract(response, "avatar", user);
			s.dirty = true;
			pushEvent(s, EVENT_READY);
			return true;
		}

		void sleepUnlessStopped(int milliseconds)
		{
			int left = milliseconds;
			while (left > 0 && isRunning())
			{
				int step = left > 250 ? 250 : left;
				platform::wait(step);
				left -= step;
			}
		}

		void run()
		{
			State &s = state();
			std::string buffer;
			int backoff = 2000;
			while (isRunning())
			{
				if (!platform::pipeIsOpen())
				{
					setStatus(STATUS_CONNECTING);
					buffer.clear();
					if (platform::pipeOpen() && handshake(buffer))
					{
						setStatus(STATUS_CONNECTED);
						backoff = 2000;
					}
					else
					{
						platform::pipeClose();
						setStatus(STATUS_DISCONNECTED);
						sleepUnlessStopped(backoff);
						backoff = backoff < 30000 ? backoff * 2 : 30000;
						continue;
					}
				}

				Activity toSend;
				bool send = false;
				uint64_t nonce = 0;
				{
					platform::Guard guard;
					if (s.dirty)
					{
						toSend = s.pending;
						s.dirty = false;
						send = true;
						nonce = ++s.nonce;
					}
				}
				if (send && !writeFrame(OP_FRAME, activityJson(toSend, nonce)))
				{
					platform::Guard guard;
					s.dirty = true;
				}

				uint32_t opcode = 0;
				std::string payload;
				while (platform::pipeIsOpen() && readFrame(buffer, opcode, payload, 0))
				{
					if (opcode == OP_PING) writeFrame(OP_PONG, payload);
					else if (opcode == OP_CLOSE)
					{
						recordError(payload, false);
						platform::pipeClose();
					}
					else if (opcode == OP_FRAME && payload.find("\"evt\":\"ERROR\"") != std::string::npos) recordError(payload, true);
				}

				if (!platform::pipeIsOpen())
				{
					platform::Guard guard;
					s.status = STATUS_DISCONNECTED;
					s.dirty = true;
					pushEvent(s, EVENT_DISCONNECTED);
					continue;
				}

				bool pendingWork = false;
				{
					platform::Guard guard;
					pendingWork = s.dirty || !s.running;
				}
				if (!pendingWork) platform::wait(250);
			}

			if (platform::pipeIsOpen())
			{
				Activity empty;
				uint64_t nonce = 0;
				{
					platform::Guard guard;
					nonce = ++s.nonce;
				}
				writeFrame(OP_FRAME, activityJson(empty, nonce));
			}
			platform::pipeClose();
			setStatus(STATUS_DISCONNECTED);
		}

		std::string &returned()
		{
			static std::string value;
			return value;
		}

		const char *give(const std::string &value)
		{
			returned() = value;
			return returned().c_str();
		}
	}

	bool supported()
	{
		return platform::supported();
	}

	void start(const char *clientId)
	{
		if (!platform::supported()) return;
		stop();
		State &s = state();
		{
			platform::Guard guard;
			s.clientId = clientId != nullptr ? clientId : "";
			s.eventHead = 0;
			s.eventCount = 0;
			s.dirty = true;
			s.running = true;
		}
		if (!platform::startThread(run))
		{
			platform::Guard guard;
			s.running = false;
		}
	}

	void stop()
	{
		if (!platform::supported()) return;
		{
			platform::Guard guard;
			state().running = false;
		}
		platform::notify();
		platform::joinThread();
		setStatus(STATUS_DISCONNECTED);
	}

	int status()
	{
		if (!platform::supported()) return STATUS_UNSUPPORTED;
		platform::Guard guard;
		return state().status;
	}

	int pollEvent()
	{
		State &s = state();
		platform::Guard guard;
		if (s.eventCount == 0) return EVENT_NONE;
		int event = s.events[s.eventHead];
		s.eventHead = (s.eventHead + 1) % EVENT_CAPACITY;
		s.eventCount--;
		return event;
	}

	void setActivity(int type, const char *details, const char *stateText, const char *largeImage, const char *largeText, const char *smallImage,
		const char *smallText, double startTimestamp, double endTimestamp)
	{
		platform::Guard guard;
		Activity &a = state().staged;
		a.type = type;
		a.details = clip(details, 128);
		a.state = clip(stateText, 128);
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
		platform::Guard guard;
		Activity &a = state().staged;
		a.partyId = clip(id, 128);
		a.partySize = size;
		a.partyMax = max;
	}

	void setButton(int index, const char *label, const char *url)
	{
		if (index < 0 || index > 1) return;
		platform::Guard guard;
		Button &button = state().staged.buttons[index];
		button.label = clip(label, 32);
		button.url = clip(url, 512);
	}

	void clearButtons()
	{
		platform::Guard guard;
		Activity &a = state().staged;
		a.buttons[0] = Button();
		a.buttons[1] = Button();
	}

	void commit()
	{
		{
			platform::Guard guard;
			State &s = state();
			s.pending = s.staged;
			s.dirty = true;
		}
		platform::notify();
	}

	void clearActivity()
	{
		{
			platform::Guard guard;
			State &s = state();
			s.staged = Activity();
			s.pending = Activity();
			s.dirty = true;
		}
		platform::notify();
	}

	const char *userId()
	{
		platform::Guard guard;
		return give(state().userId);
	}

	const char *userName()
	{
		platform::Guard guard;
		return give(state().userName);
	}

	const char *globalName()
	{
		platform::Guard guard;
		return give(state().globalName);
	}

	const char *avatar()
	{
		platform::Guard guard;
		return give(state().avatar);
	}

	const char *lastError()
	{
		platform::Guard guard;
		return give(state().error);
	}

	int lastErrorCode()
	{
		platform::Guard guard;
		return state().errorCode;
	}

	const char *platformName()
	{
		return platform::name();
	}
}
