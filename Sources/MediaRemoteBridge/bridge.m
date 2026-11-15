#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*RegisterFn)(dispatch_queue_t);
typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetClientFn)(dispatch_queue_t, void (^)(id));
typedef NSString *(*ClientDisplayNameFn)(id);
typedef BOOL (*SendCommandFn)(uint32_t, id);

static void *mrHandle = NULL;
static GetInfoFn getInfoFn = NULL;
static GetClientFn getClientFn = NULL;
static ClientDisplayNameFn clientNameFn = NULL;
static SendCommandFn sendCommandFn = NULL;

static void loadMR(void) {
    if (mrHandle) return;
    mrHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (!mrHandle) return;
    getInfoFn = (GetInfoFn)dlsym(mrHandle, "MRMediaRemoteGetNowPlayingInfo");
    getClientFn = (GetClientFn)dlsym(mrHandle, "MRMediaRemoteGetNowPlayingClient");
    clientNameFn = (ClientDisplayNameFn)dlsym(mrHandle, "MRNowPlayingClientGetDisplayName");
    sendCommandFn = (SendCommandFn)dlsym(mrHandle, "MRMediaRemoteSendCommand");
}

static void emitSnapshot(void) {
    if (!getInfoFn) return;
    getInfoFn(dispatch_get_main_queue(), ^(NSDictionary *info) {
        NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
        if (![title isKindOfClass:[NSString class]] || title.length == 0) {
            printf("{\"empty\":true}\n");
            fflush(stdout);
            return;
        }

        NSString *artist = [info[@"kMRMediaRemoteNowPlayingInfoArtist"] isKindOfClass:[NSString class]]
            ? info[@"kMRMediaRemoteNowPlayingInfoArtist"] : @"";
        NSString *album = [info[@"kMRMediaRemoteNowPlayingInfoAlbum"] isKindOfClass:[NSString class]]
            ? info[@"kMRMediaRemoteNowPlayingInfoAlbum"] : @"";
        double duration = [info[@"kMRMediaRemoteNowPlayingInfoDuration"] respondsToSelector:@selector(doubleValue)]
            ? [info[@"kMRMediaRemoteNowPlayingInfoDuration"] doubleValue] : 0.0;
        double elapsed = [info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] respondsToSelector:@selector(doubleValue)]
            ? [info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] doubleValue] : 0.0;
        double rate = [info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] respondsToSelector:@selector(doubleValue)]
            ? [info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] doubleValue] : 0.0;
        NSDate *ts = [info[@"kMRMediaRemoteNowPlayingInfoTimestamp"] isKindOfClass:[NSDate class]]
            ? info[@"kMRMediaRemoteNowPlayingInfoTimestamp"] : nil;
        double timestamp = ts ? [ts timeIntervalSince1970] : 0.0;
        NSData *artData = [info[@"kMRMediaRemoteNowPlayingInfoArtworkData"] isKindOfClass:[NSData class]]
            ? info[@"kMRMediaRemoteNowPlayingInfoArtworkData"] : nil;
        NSString *artBase64 = artData ? [artData base64EncodedStringWithOptions:0] : @"";

        void (^writeLine)(NSString *) = ^(NSString *source) {
            NSDictionary *payload = @{
                @"title": title,
                @"artist": artist,
                @"album": album,
                @"source": source ?: @"Now Playing",
                @"duration": @(duration),
                @"elapsed": @(elapsed),
                @"playbackRate": @(rate),
                @"timestamp": @(timestamp),
                @"artworkBase64": artBase64
            };
            NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
            if (json) {
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
                fflush(stdout);
            }
        };

        if (getClientFn && clientNameFn) {
            getClientFn(dispatch_get_main_queue(), ^(id client) {
                NSString *name = client ? clientNameFn(client) : nil;
                writeLine(name.length > 0 ? name : @"Now Playing");
            });
        } else {
            writeLine(@"Now Playing");
        }
    });
}

void mr_stream(void) {
    @autoreleasepool {
        loadMR();
        if (!mrHandle) return;
        RegisterFn reg = (RegisterFn)dlsym(mrHandle, "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (reg) reg(dispatch_get_main_queue());

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
        ];
        for (NSString *name in names) {
            [nc addObserverForName:name object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                (void)note;
                emitSnapshot();
            }];
        }

        emitSnapshot();
        CFRunLoopRun();
    }
}

static void sendCmd(uint32_t cmd) {
    @autoreleasepool {
        loadMR();
        if (sendCommandFn) {
            sendCommandFn(cmd, nil);
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
        }
    }
}

void mr_cmd_toggle(void) { sendCmd(2); }
void mr_cmd_next(void)   { sendCmd(4); }
void mr_cmd_prev(void)   { sendCmd(5); }

