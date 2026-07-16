#include <Carbon/Carbon.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define MAX_HOTKEYS 64
#define HOTKEY_NAME_LEN 128
#define SIGNATURE 'PGHK'

typedef struct {
    EventHotKeyRef ref;
    UInt32 id;
    char name[HOTKEY_NAME_LEN];
} HotkeyRegistration;

static int socket_fd = -1;
static struct sockaddr_un socket_addr;
static socklen_t socket_addr_len = 0;
static HotkeyRegistration registrations[MAX_HOTKEYS];
static int registration_count = 0;
static volatile sig_atomic_t should_stop = 0;

static void handle_signal(int signal_number) {
    (void)signal_number;
    should_stop = 1;
}

static int key_code_for_name(const char *name, UInt32 *key_code) {
    static const struct { const char *name; UInt32 code; } keys[] = {
        {"a", kVK_ANSI_A}, {"b", kVK_ANSI_B}, {"c", kVK_ANSI_C}, {"d", kVK_ANSI_D},
        {"e", kVK_ANSI_E}, {"f", kVK_ANSI_F}, {"g", kVK_ANSI_G}, {"h", kVK_ANSI_H},
        {"i", kVK_ANSI_I}, {"j", kVK_ANSI_J}, {"k", kVK_ANSI_K}, {"l", kVK_ANSI_L},
        {"m", kVK_ANSI_M}, {"n", kVK_ANSI_N}, {"o", kVK_ANSI_O}, {"p", kVK_ANSI_P},
        {"q", kVK_ANSI_Q}, {"r", kVK_ANSI_R}, {"s", kVK_ANSI_S}, {"t", kVK_ANSI_T},
        {"u", kVK_ANSI_U}, {"v", kVK_ANSI_V}, {"w", kVK_ANSI_W}, {"x", kVK_ANSI_X},
        {"y", kVK_ANSI_Y}, {"z", kVK_ANSI_Z}, {"0", kVK_ANSI_0}, {"1", kVK_ANSI_1},
        {"2", kVK_ANSI_2}, {"3", kVK_ANSI_3}, {"4", kVK_ANSI_4}, {"5", kVK_ANSI_5},
        {"6", kVK_ANSI_6}, {"7", kVK_ANSI_7}, {"8", kVK_ANSI_8}, {"9", kVK_ANSI_9},
        {"space", kVK_Space}, {"tab", kVK_Tab}, {"enter", kVK_Return}, {"return", kVK_Return},
        {"esc", kVK_Escape}, {"escape", kVK_Escape}, {"f1", kVK_F1}, {"f2", kVK_F2},
        {"f3", kVK_F3}, {"f4", kVK_F4}, {"f5", kVK_F5}, {"f6", kVK_F6},
        {"f7", kVK_F7}, {"f8", kVK_F8}, {"f9", kVK_F9}, {"f10", kVK_F10},
        {"f11", kVK_F11}, {"f12", kVK_F12},
    };

    for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        if (strcmp(name, keys[i].name) == 0) {
            *key_code = keys[i].code;
            return 1;
        }
    }
    return 0;
}

static int parse_hotkey(const char *hotkey, UInt32 *key_code, UInt32 *modifiers) {
    char buffer[HOTKEY_NAME_LEN];
    char *token;
    char *saveptr = NULL;
    char *main_key = NULL;

    if (strlen(hotkey) >= sizeof(buffer)) {
        return 0;
    }

    strcpy(buffer, hotkey);
    *modifiers = 0;

    for (token = strtok_r(buffer, "+", &saveptr); token; token = strtok_r(NULL, "+", &saveptr)) {
        if (strcmp(token, "ctrl") == 0 || strcmp(token, "control") == 0 || strcmp(token, "ctl") == 0) {
            *modifiers |= controlKey;
        } else if (strcmp(token, "shift") == 0) {
            *modifiers |= shiftKey;
        } else if (strcmp(token, "alt") == 0 || strcmp(token, "option") == 0 || strcmp(token, "opt") == 0) {
            *modifiers |= optionKey;
        } else if (strcmp(token, "cmd") == 0 || strcmp(token, "command") == 0) {
            *modifiers |= cmdKey;
        } else {
            main_key = token;
        }
    }

    if (!main_key || *modifiers == 0) {
        return 0;
    }

    return key_code_for_name(main_key, key_code);
}

static OSStatus hotkey_handler(EventHandlerCallRef next_handler, EventRef event, void *user_data) {
    (void)next_handler;
    (void)user_data;

    EventHotKeyID hotkey_id;
    OSStatus status = GetEventParameter(
        event,
        kEventParamDirectObject,
        typeEventHotKeyID,
        NULL,
        sizeof(hotkey_id),
        NULL,
        &hotkey_id
    );

    if (status != noErr) {
        return status;
    }

    for (int i = 0; i < registration_count; i++) {
        if (registrations[i].id == hotkey_id.id) {
            sendto(
                socket_fd,
                registrations[i].name,
                strlen(registrations[i].name),
                0,
                (struct sockaddr *)&socket_addr,
                socket_addr_len
            );
            break;
        }
    }

    return noErr;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <socket-path> <hotkey> [hotkey...]\n", argv[0]);
        return 2;
    }

    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);

    socket_fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (socket_fd < 0) {
        perror("socket");
        return 1;
    }

    memset(&socket_addr, 0, sizeof(socket_addr));
    socket_addr.sun_family = AF_UNIX;
    strncpy(socket_addr.sun_path, argv[1], sizeof(socket_addr.sun_path) - 1);
    socket_addr_len = (socklen_t)(offsetof(struct sockaddr_un, sun_path) + strlen(socket_addr.sun_path));

    EventTypeSpec event_type = { kEventClassKeyboard, kEventHotKeyPressed };
    EventTargetRef target = GetEventDispatcherTarget();
    OSStatus status = InstallEventHandler(target, hotkey_handler, 1, &event_type, NULL, NULL);
    if (status != noErr) {
        fprintf(stderr, "InstallEventHandler failed: %d\n", (int)status);
        return 1;
    }

    for (int arg = 2; arg < argc && registration_count < MAX_HOTKEYS; arg++) {
        UInt32 key_code = 0;
        UInt32 modifiers = 0;
        if (!parse_hotkey(argv[arg], &key_code, &modifiers)) {
            fprintf(stderr, "Unsupported hotkey: %s\n", argv[arg]);
            continue;
        }

        EventHotKeyID hotkey_id = { SIGNATURE, (UInt32)(registration_count + 1) };
        status = RegisterEventHotKey(key_code, modifiers, hotkey_id, target, 0, &registrations[registration_count].ref);
        if (status != noErr) {
            fprintf(stderr, "RegisterEventHotKey failed for %s: %d\n", argv[arg], (int)status);
            continue;
        }

        registrations[registration_count].id = hotkey_id.id;
        strncpy(registrations[registration_count].name, argv[arg], HOTKEY_NAME_LEN - 1);
        registration_count++;
    }

    if (registration_count == 0) {
        fprintf(stderr, "No hotkeys registered\n");
        return 1;
    }

    printf("registered %d hotkeys\n", registration_count);
    fflush(stdout);

    while (!should_stop) {
        EventRef event = NULL;
        status = ReceiveNextEvent(0, NULL, 1.0, true, &event);
        if (status == noErr && event) {
            SendEventToEventTarget(event, target);
            ReleaseEvent(event);
        }
    }

    for (int i = 0; i < registration_count; i++) {
        if (registrations[i].ref) {
            UnregisterEventHotKey(registrations[i].ref);
        }
    }
    close(socket_fd);
    return 0;
}
