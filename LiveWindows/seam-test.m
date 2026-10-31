// Target-machine test: what the window server shows between a handoff's native move and its transaction,
// on this tool's own windows through the loaded add-on. A thread polls the subject's transform at ~20 µs
// and prints every distinct drawn position with its time; "off its spot" after the handoff is the blink
// that add-on sunlight-15 removed (the move now goes in the transaction). Needs the add-on loaded; no TCC grants.
// Build: clang -fobjc-arc LiveWindows/seam-test.m -framework Cocoa -F/System/Library/PrivateFrameworks -framework SkyLight -o /tmp/sunbeam-seam-test
#import <Cocoa/Cocoa.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <pwd.h>
#include <unistd.h>
#include <pthread.h>
#include <mach/mach_time.h>
extern int SLSMainConnectionID(void);
extern CGError SLSGetWindowTransform(int, uint32_t, CGAffineTransform *);
extern CGError SLSGetWindowBounds(int cid, uint32_t wid, CGRect *frame);

static int connection(uint8_t op) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    snprintf(address.sun_path, sizeof(address.sun_path), "/tmp/sunlight-live_%s.socket", getpwuid(getuid())->pw_name);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) { perror("connect"); exit(2); }
    struct timeval timeout = {.tv_sec = 2};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    uint8_t bytes[] = {1, 0, op}; send(fd, bytes, 3, 0);
    char magic[9];
    if (recv(fd, magic, 9, MSG_WAITALL) != 9 || memcmp(magic, "SUNBEAM1\n", 9)) { fprintf(stderr, "add-on not loaded\n"); exit(2); }
    return fd;
}
static void frame(int fd, uint32_t wid, uint32_t backdrop, uint32_t overlay, float zoom, float x, float y) {
    char bytes[42] = {0}; int16_t length = 40; uint16_t count = 1;
    float matrix[] = {1/zoom, 0, 0, 1/zoom, -x/zoom, -y/zoom};
    memcpy(bytes, &length, 2); bytes[2] = 0x72;
    memcpy(bytes + 3, &backdrop, 4); memcpy(bytes + 7, &overlay, 4); memcpy(bytes + 11, &count, 2);
    bytes[13] = 1;   // full
    memcpy(bytes + 14, &wid, 4); memcpy(bytes + 18, matrix, 24);
    if (send(fd, bytes, 42, 0) != 42) { perror("send"); exit(3); }
    uint8_t ack = 1;
    if (recv(fd, &ack, 1, MSG_WAITALL) != 1 || ack != 0) { fprintf(stderr, "frame rejected %d\n", ack); exit(3); }
}
static void handoff(int fd, uint32_t wid, float x, float y, uint32_t overlay, uint32_t backdrop) {
    char bytes[23]; int16_t length = 21;
    memcpy(bytes, &length, 2); bytes[2] = 0x73; memcpy(bytes+3, &wid, 4); memcpy(bytes+7, &x, 4); memcpy(bytes+11, &y, 4);
    memcpy(bytes+15, &overlay, 4); memcpy(bytes+19, &backdrop, 4);
    if (send(fd, bytes, 23, 0) != 23) { perror("send"); exit(3); }
    uint8_t ack = 1;
    if (recv(fd, &ack, 1, MSG_WAITALL) != 1 || ack != 0) { fprintf(stderr, "handoff rejected %d\n", ack); exit(3); }
}
static NSWindow *window(NSRect rect, NSColor *color, NSString *title) {
    NSWindow *w = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    w.releasedWhenClosed = NO; w.backgroundColor = color; w.title = title; w.opaque = NO;
    [w orderFront:nil]; return w;
}
static void run(double seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (until.timeIntervalSinceNow > 0) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
}
// Poller
static uint32_t pollWid; static volatile int polling = 1;
struct sample { double t; double zoom, dx, dy; double nx, ny; };
static struct sample samples[100000]; static int sampleCount;
static double now(void) { static mach_timebase_info_data_t tb; if (!tb.denom) mach_timebase_info(&tb); return mach_absolute_time() * tb.numer / (double)tb.denom / 1e6; }
static void *poll(void *unused) {
    int cid = SLSMainConnectionID();
    struct sample last = {0};
    while (polling) {
        CGAffineTransform t; CGRect b;
        if (SLSGetWindowTransform(cid, pollWid, &t) != 0) continue;
        SLSGetWindowBounds(cid, pollWid, &b);
        struct sample s = { now(), 1.0 / t.a, -t.tx / t.a, -t.ty / t.a, b.origin.x, b.origin.y };
        if (fabs(s.zoom - last.zoom) > 1e-3 || fabs(s.dx - last.dx) > 0.5 || fabs(s.dy - last.dy) > 0.5 || fabs(s.nx - last.nx) > 0.5 || fabs(s.ny - last.ny) > 0.5) {
            if (sampleCount < 100000) samples[sampleCount++] = s;
            last = s;
        }
    }
    return NULL;
}
int main(int argc, char **argv) {
    @autoreleasepool {
        int rounds = argc > 1 ? atoi(argv[1]) : 5;
        [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        // Cocoa's y is bottom-up; the window server's top-left. On a 982-pt-high screen (menu bar 33): keep it simple, read back.
        NSWindow *backdrop = window(NSMakeRect(50, 50, 1300, 800), [NSColor colorWithWhite:0.15 alpha:1], @"seam backdrop");
        NSWindow *subject = window(NSMakeRect(100, 500, 400, 300), NSColor.systemTealColor, @"seam subject");
        NSWindow *overlay = window(backdrop.frame, NSColor.clearColor, @"seam overlay");
        overlay.ignoresMouseEvents = YES;
        run(0.3);
        uint32_t wid = (uint32_t)subject.windowNumber, bd = (uint32_t)backdrop.windowNumber, ov = (uint32_t)overlay.windowNumber;
        pollWid = wid;
        CGRect native; SLSGetWindowBounds(SLSMainConnectionID(), wid, &native);
        printf("subject %u native at (%.0f,%.0f)\n", wid, native.origin.x, native.origin.y);
        pthread_t thread; pthread_create(&thread, NULL, poll, NULL);
        for (int r = 0; r < rounds; ++r) {
            // Native back where it started (the handoff moved it), then a frame drawing it 700 pt to the right.
            [subject setFrameOrigin:NSMakePoint(100, 500)]; run(0.2);
            SLSGetWindowBounds(SLSMainConnectionID(), wid, &native);
            float x = native.origin.x + 700, y = native.origin.y + 200;
            int fd = connection(0x71);
            frame(fd, wid, bd, ov, 1, x, y); run(0.2);
            sampleCount = 0;
            double t0 = now();
            handoff(fd, wid, x, y, ov, bd);
            double t1 = now();
            run(0.1);
            printf("round %d: handoff to (%.0f,%.0f) acked in %.2f ms; distinct states seen:\n", r, x, y, t1 - t0);
            for (int i = 0; i < sampleCount; ++i)
                printf("  +%7.3f ms  drawn %.2fx@(%.0f,%.0f)  native (%.0f,%.0f)%s\n", samples[i].t - t0, samples[i].zoom, samples[i].dx, samples[i].dy, samples[i].nx, samples[i].ny,
                       (fabs(samples[i].dx - x) > 1 || fabs(samples[i].dy - y) > 1) && samples[i].t >= t0 ? "   <-- off its spot" : "");
            close(fd); run(0.3);
        }
        polling = 0; pthread_join(thread, NULL);
    }
    return 0;
}
