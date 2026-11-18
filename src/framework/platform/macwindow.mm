/*
 * Native Cocoa / NSOpenGL window backend for macOS (no XQuartz).
 */

#ifdef __APPLE__

// GLEW must load before any system OpenGL/AppKit headers.
#ifndef _MSC_VER
#define GLEW_STATIC
#endif
#include <GL/glew.h>

// MacTypes.h also defines Point/Size/Rect — rename them before AppKit.
#define Point MacPoint
#define Size MacSize
#define Rect MacRect
#import <AppKit/AppKit.h>
#undef Point
#undef Size
#undef Rect
// AppKit/CarbonEvents sets EVENT_H; our event.h uses the same include guard.
#undef EVENT_H

#include "macwindow.h"

#include <framework/core/application.h>
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/image.h>
#include <framework/util/stats.h>

// Virtual key codes (Carbon HIToolbox) — hardcoded to avoid Carbon headers.
enum {
    kVK_Return = 0x24,
    kVK_Tab = 0x30,
    kVK_Space = 0x31,
    kVK_Delete = 0x33,
    kVK_Escape = 0x35,
    kVK_Command = 0x37,
    kVK_Shift = 0x38,
    kVK_CapsLock = 0x39,
    kVK_Option = 0x3A,
    kVK_Control = 0x3B,
    kVK_RightCommand = 0x36,
    kVK_RightShift = 0x3C,
    kVK_RightOption = 0x3D,
    kVK_RightControl = 0x3E,
    kVK_F5 = 0x60,
    kVK_F6 = 0x61,
    kVK_F7 = 0x62,
    kVK_F3 = 0x63,
    kVK_F8 = 0x64,
    kVK_F9 = 0x65,
    kVK_F11 = 0x67,
    kVK_F10 = 0x6D,
    kVK_F12 = 0x6F,
    kVK_Home = 0x73,
    kVK_PageUp = 0x74,
    kVK_ForwardDelete = 0x75,
    kVK_F4 = 0x76,
    kVK_End = 0x77,
    kVK_F2 = 0x78,
    kVK_PageDown = 0x79,
    kVK_F1 = 0x7A,
    kVK_LeftArrow = 0x7B,
    kVK_RightArrow = 0x7C,
    kVK_DownArrow = 0x7D,
    kVK_UpArrow = 0x7E,
    kVK_ANSI_Keypad0 = 0x52,
    kVK_ANSI_Keypad1 = 0x53,
    kVK_ANSI_Keypad2 = 0x54,
    kVK_ANSI_Keypad3 = 0x55,
    kVK_ANSI_Keypad4 = 0x56,
    kVK_ANSI_Keypad5 = 0x57,
    kVK_ANSI_Keypad6 = 0x58,
    kVK_ANSI_Keypad7 = 0x59,
    kVK_ANSI_Keypad8 = 0x5B,
    kVK_ANSI_Keypad9 = 0x5C,
    kVK_ANSI_KeypadEnter = 0x4C,
};

@class OTCGLView;
@class OTCAppDelegate;


static int currentKeyboardModifiers()
{
    NSUInteger flags = [NSEvent modifierFlags];
    int mods = 0;
    if (flags & NSEventModifierFlagControl)
        mods |= Fw::KeyboardCtrlModifier;
    if (flags & NSEventModifierFlagShift)
        mods |= Fw::KeyboardShiftModifier;
    if (flags & NSEventModifierFlagOption)
        mods |= Fw::KeyboardAltModifier;
    return mods;
}

static Fw::Key mapMacKeyCode(unsigned short keyCode, NSString* chars)
{
    switch (keyCode) {
        case kVK_Escape: return Fw::KeyEscape;
        case kVK_Tab: return Fw::KeyTab;
        case kVK_Return: return Fw::KeyEnter;
        case kVK_ANSI_KeypadEnter: return Fw::KeyEnter;
        case kVK_Delete: return Fw::KeyBackspace;
        case kVK_ForwardDelete: return Fw::KeyDelete;
        case kVK_Space: return Fw::KeySpace;
        case kVK_Home: return Fw::KeyHome;
        case kVK_End: return Fw::KeyEnd;
        case kVK_PageUp: return Fw::KeyPageUp;
        case kVK_PageDown: return Fw::KeyPageDown;
        case kVK_LeftArrow: return Fw::KeyLeft;
        case kVK_RightArrow: return Fw::KeyRight;
        case kVK_UpArrow: return Fw::KeyUp;
        case kVK_DownArrow: return Fw::KeyDown;
        case kVK_F1: return Fw::KeyF1;
        case kVK_F2: return Fw::KeyF2;
        case kVK_F3: return Fw::KeyF3;
        case kVK_F4: return Fw::KeyF4;
        case kVK_F5: return Fw::KeyF5;
        case kVK_F6: return Fw::KeyF6;
        case kVK_F7: return Fw::KeyF7;
        case kVK_F8: return Fw::KeyF8;
        case kVK_F9: return Fw::KeyF9;
        case kVK_F10: return Fw::KeyF10;
        case kVK_F11: return Fw::KeyF11;
        case kVK_F12: return Fw::KeyF12;
        case kVK_ANSI_Keypad0: return Fw::KeyNumpad0;
        case kVK_ANSI_Keypad1: return Fw::KeyNumpad1;
        case kVK_ANSI_Keypad2: return Fw::KeyNumpad2;
        case kVK_ANSI_Keypad3: return Fw::KeyNumpad3;
        case kVK_ANSI_Keypad4: return Fw::KeyNumpad4;
        case kVK_ANSI_Keypad5: return Fw::KeyNumpad5;
        case kVK_ANSI_Keypad6: return Fw::KeyNumpad6;
        case kVK_ANSI_Keypad7: return Fw::KeyNumpad7;
        case kVK_ANSI_Keypad8: return Fw::KeyNumpad8;
        case kVK_ANSI_Keypad9: return Fw::KeyNumpad9;
        case kVK_Control:
        case kVK_RightControl:
        case kVK_Shift:
        case kVK_RightShift:
        case kVK_Option:
        case kVK_RightOption:
        case kVK_Command:
        case kVK_RightCommand:
            return Fw::KeyUnknown;
        default:
            break;
    }

    if (chars && [chars length] > 0) {
        unichar c = [[chars lowercaseString] characterAtIndex:0];
        if (c >= 'a' && c <= 'z')
            return static_cast<Fw::Key>(Fw::KeyA + (c - 'a'));
        if (c >= '0' && c <= '9')
            return static_cast<Fw::Key>(Fw::Key0 + (c - '0'));
        switch (c) {
            case ' ': return Fw::KeySpace;
            case '-': return Fw::KeyMinus;
            case '=': return Fw::KeyEqual;
            case '[': return Fw::KeyLeftBracket;
            case ']': return Fw::KeyRightBracket;
            case '\\': return Fw::KeyBackslash;
            case ';': return Fw::KeySemicolon;
            case '\'': return Fw::KeyApostrophe;
            case ',': return Fw::KeyComma;
            case '.': return Fw::KeyPeriod;
            case '/': return Fw::KeySlash;
            case '`': return Fw::KeyGrave;
        }
    }
    return Fw::KeyUnknown;
}

@interface OTCGLView : NSOpenGLView <NSTextInputClient>
@property(nonatomic, assign) MacWindow* owner;
@property(nonatomic, copy) NSString* markedTextString;
@property(nonatomic, assign) NSRange markedTextRange;
@property(nonatomic, assign) NSRange inputSelectedRange;
@end

@implementation OTCGLView
- (BOOL)acceptsFirstResponder { return YES; }

- (void)reshape
{
    [super reshape];
    if (!self.owner)
        return;
    NSRect bounds = [self bounds];
    self.owner->handleResize((int)bounds.size.width, (int)bounds.size.height);
}

- (Point)mousePointFromEvent:(NSEvent*)event
{
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    // Cocoa y is bottom-up; client uses top-left origin
    p.y = [self bounds].size.height - p.y;
    return Point((int)p.x, (int)p.y);
}

- (void)mouseMoved:(NSEvent*)event
{
    if (self.owner)
        self.owner->handleMouseMove([self mousePointFromEvent:event]);
}
- (void)mouseDragged:(NSEvent*)event { [self mouseMoved:event]; }
- (void)rightMouseDragged:(NSEvent*)event { [self mouseMoved:event]; }
- (void)otherMouseDragged:(NSEvent*)event { [self mouseMoved:event]; }

- (void)mouseDown:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMousePress(Fw::MouseLeftButton);
}
- (void)mouseUp:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMouseRelease(Fw::MouseLeftButton);
}
- (void)rightMouseDown:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMousePress(Fw::MouseRightButton);
}
- (void)rightMouseUp:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMouseRelease(Fw::MouseRightButton);
}
- (void)otherMouseDown:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMousePress(Fw::MouseMidButton);
}
- (void)otherMouseUp:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->handleMouseMove([self mousePointFromEvent:event]);
    self.owner->handleMouseRelease(Fw::MouseMidButton);
}
- (void)scrollWheel:(NSEvent*)event
{
    if (!self.owner) return;
    if ([event deltaY] > 0)
        self.owner->handleMouseWheel(Fw::MouseWheelUp);
    else if ([event deltaY] < 0)
        self.owner->handleMouseWheel(Fw::MouseWheelDown);
}

static bool isMacOptionTextKey(Fw::Key key)
{
    if (key >= Fw::Key0 && key <= Fw::Key9)
        return true;
    if (key >= Fw::KeyA && key <= Fw::KeyZ)
        return true;
    switch (key) {
        case Fw::KeySpace:
        case Fw::KeyMinus:
        case Fw::KeyEqual:
        case Fw::KeyLeftBracket:
        case Fw::KeyRightBracket:
        case Fw::KeyBackslash:
        case Fw::KeySemicolon:
        case Fw::KeyApostrophe:
        case Fw::KeyGrave:
        case Fw::KeyComma:
        case Fw::KeyPeriod:
        case Fw::KeySlash:
            return true;
        default:
            return false;
    }
}

- (void)keyDown:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->updateModifiers(currentKeyboardModifiers());

    NSUInteger mods = [event modifierFlags];
    bool ctrlCmd = (mods & (NSEventModifierFlagControl | NSEventModifierFlagCommand)) != 0;
    bool option = (mods & NSEventModifierFlagOption) != 0;
    bool composing = [self hasMarkedText];

    Fw::Key key = mapMacKeyCode([event keyCode], [event charactersIgnoringModifiers]);
    if (key != Fw::KeyUnknown && !composing) {
        // Option+key produces alternate Unicode on many layouts (not a game chord).
        if (!(option && isMacOptionTextKey(key)))
            self.owner->handleKeyDown(key);
    }

    if (ctrlCmd)
        return;

    // Dead-key / IME composition (e.g. ~ then a → ã)
    if (composing || ![event characters] || [[event characters] length] == 0) {
        [[self inputContext] handleEvent:event];
        return;
    }

    NSString* chars = [event characters];
    unichar c = [chars characterAtIndex:0];
    // Skip arrows/function keys (NSF*FunctionKey range) and ASCII controls
    if (c < 32 || c == 127 || (c >= 0xF700 && c <= 0xF8FF)) {
        [[self inputContext] handleEvent:event];
        return;
    }
    if (key == Fw::KeyEnter || key == Fw::KeyEscape || key == Fw::KeyBackspace ||
        key == Fw::KeyDelete || key == Fw::KeyTab)
        return;

    // Direct Unicode from the layout (ç, ñ, /, letters, …). More reliable than
    // interpretKeyEvents alone for ABNT/PT keys that already produce a character.
    [self emitTextInput:chars];
}

- (void)keyUp:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->updateModifiers(currentKeyboardModifiers());
    Fw::Key key = mapMacKeyCode([event keyCode], [event charactersIgnoringModifiers]);
    if (key != Fw::KeyUnknown)
        self.owner->handleKeyUp(key);
}

- (void)flagsChanged:(NSEvent*)event
{
    if (!self.owner) return;
    self.owner->updateModifiers(currentKeyboardModifiers());
    // Ctrl/Option/Cmd transitions often swallow the matching keyUp on macOS,
    // which leaves walk keys stuck (endless walk). Clear them on modifier change.
    self.owner->releaseKeysOnModifierChange();
}

- (void)emitTextInput:(NSString*)string
{
    if (!self.owner || !string || [string length] == 0)
        return;
    NSMutableString* filtered = [NSMutableString stringWithCapacity:[string length]];
    for (NSUInteger i = 0; i < [string length]; ++i) {
        unichar c = [string characterAtIndex:i];
        if (c >= 32 && c != 127 && !(c >= 0xF700 && c <= 0xF8FF))
            [filtered appendFormat:@"%C", c];
    }
    if ([filtered length] == 0)
        return;
    // OTClient bitmap fonts index glyphs as Latin-1 bytes (uchar), not UTF-8.
    // X11 feeds Latin-1 via XmbLookupString too.
    NSData* data = [filtered dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
    if (!data || [data length] == 0)
        return;
    std::string text(static_cast<const char*>([data bytes]), [data length]);
    if (!text.empty())
        self.owner->handleTextInputEvent(text);
}

- (void)insertText:(id)insertString
{
    [self insertText:insertString replacementRange:NSMakeRange(NSNotFound, 0)];
}

- (void)doCommandBySelector:(SEL)selector
{
    // Game keys already handled via keyCode KeyDown. Swallow beeps.
    (void)selector;
}

#pragma mark - NSTextInputClient

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange
{
    (void)replacementRange;
    NSString* text = [string isKindOfClass:[NSAttributedString class]]
        ? [(NSAttributedString*)string string]
        : (NSString*)string;
    self.markedTextString = nil;
    self.markedTextRange = NSMakeRange(NSNotFound, 0);
    [self emitTextInput:text];
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange
{
    (void)replacementRange;
    NSString* text = [string isKindOfClass:[NSAttributedString class]]
        ? [(NSAttributedString*)string string]
        : (NSString*)string;
    if (!text || [text length] == 0) {
        self.markedTextString = nil;
        self.markedTextRange = NSMakeRange(NSNotFound, 0);
    } else {
        self.markedTextString = [text copy];
        self.markedTextRange = NSMakeRange(0, [text length]);
    }
    self.inputSelectedRange = selectedRange;
}

- (void)unmarkText
{
    self.markedTextString = nil;
    self.markedTextRange = NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange
{
    return self.inputSelectedRange;
}

- (NSRange)markedRange
{
    return self.markedTextRange;
}

- (BOOL)hasMarkedText
{
    return self.markedTextString != nil && [self.markedTextString length] > 0;
}

- (NSArray<NSAttributedStringKey>*)validAttributesForMarkedText
{
    return @[];
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    (void)range;
    (void)actualRange;
    return nil;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point
{
    (void)point;
    return 0;
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    (void)range;
    if (actualRange)
        *actualRange = range;
    NSRect r = NSMakeRect(0, 0, 0, 0);
    if ([self window]) {
        r = [self convertRect:NSMakeRect(0, 0, 1, 1) toView:nil];
        r = [[self window] convertRectToScreen:r];
    }
    return r;
}
@end

@interface OTCAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, assign) MacWindow* owner;
@end

@implementation OTCAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return NO;
}
// Cmd+Q / Dock Quit must not call [NSApp terminate:] → exit(). That skips
// g_http.terminate() and aborts in ~std::thread. Route through handleClose.
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender
{
    if (self.owner)
        self.owner->handleClose();
    return NSTerminateCancel;
}
- (BOOL)windowShouldClose:(NSWindow*)sender
{
    if (self.owner)
        self.owner->handleClose();
    return NO;
}
- (void)windowDidBecomeKey:(NSNotification*)notification
{
    if (self.owner)
        self.owner->handleFocus(true);
}
- (void)windowDidResignKey:(NSNotification*)notification
{
    if (self.owner)
        self.owner->handleFocus(false);
}
- (void)windowDidResize:(NSNotification*)notification
{
    if (!self.owner) return;
    NSWindow* window = notification.object;
    NSView* view = [window contentView];
    NSRect bounds = [view bounds];
    self.owner->handleResize((int)bounds.size.width, (int)bounds.size.height);
}
@end

MacWindow::MacWindow()
{
    m_minimumSize = Size(600, 480);
    m_size = Size(800, 600);
    m_hidden = true;
}

void MacWindow::init()
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        OTCAppDelegate* delegate = [[OTCAppDelegate alloc] init];
        delegate.owner = this;
        [NSApp setDelegate:delegate];
        m_appDelegate = (__bridge_retained void*)delegate;
        [NSApp finishLaunching];

        NSOpenGLPixelFormatAttribute attrs[] = {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
            0
        };
        NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
        if (!pixelFormat)
            g_logger.fatal("Failed to create NSOpenGLPixelFormat");

        NSRect contentRect = NSMakeRect(0, 0, m_size.width(), m_size.height());
        OTCGLView* view = [[OTCGLView alloc] initWithFrame:contentRect pixelFormat:pixelFormat];
        view.owner = this;
        // Keep 1:1 pixel mapping (avoid retina scale surprises for MVP)
        [view setWantsBestResolutionOpenGLSurface:NO];
        m_glView = (__bridge_retained void*)view;

        NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
        NSWindow* window = [[NSWindow alloc] initWithContentRect:contentRect
                                                       styleMask:style
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setDelegate:delegate];
        [window setContentView:view];
        [window setAcceptsMouseMovedEvents:YES];
        [window setReleasedWhenClosed:NO];
        [window setTitle:[NSString stringWithUTF8String:g_app.getName().c_str()]];
        [window setContentMinSize:NSMakeSize(m_minimumSize.width(), m_minimumSize.height())];

        Size display = getDisplaySize();
        m_position = ((display - m_size) / 2).toPoint();
        [window setFrameOrigin:NSMakePoint(m_position.x, display.height() - m_position.y - m_size.height())];

        m_window = (__bridge_retained void*)window;
        m_defaultCursor = (__bridge void*)[NSCursor arrowCursor];
        m_created = true;

        [[view openGLContext] makeCurrentContext];
        m_hidden = true;
        m_visible = false;
    }
}

void MacWindow::terminate()
{
    @autoreleasepool {
        [NSOpenGLContext clearCurrentContext];

        // Drop ObjC -> C++ back-pointers first so close/resize cannot re-enter.
        if (m_glView) {
            OTCGLView* view = (__bridge OTCGLView*)m_glView;
            view.owner = nil;
        }
        if (m_appDelegate) {
            OTCAppDelegate* delegate = (__bridge OTCAppDelegate*)m_appDelegate;
            delegate.owner = nil;
            if ([NSApp delegate] == delegate)
                [NSApp setDelegate:nil];
        }

        if (m_window) {
            NSWindow* window = (__bridge_transfer NSWindow*)m_window;
            [window setDelegate:nil];
            [window orderOut:nil];
            m_window = nullptr;
        }
        if (m_glView) {
            (void)(__bridge_transfer OTCGLView*)m_glView;
            m_glView = nullptr;
        }
        if (m_appDelegate) {
            (void)(__bridge_transfer OTCAppDelegate*)m_appDelegate;
            m_appDelegate = nullptr;
        }
        for (void* c : m_cursors)
            (void)(__bridge_transfer NSCursor*)c;
        m_cursors.clear();
        m_defaultCursor = nullptr;
        m_created = false;
    }
}

void MacWindow::move(const Point& pos)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::move, this, pos));
        return;
    }
    m_position = pos;
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (!window) return;
        Size display = getDisplaySize();
        [window setFrameOrigin:NSMakePoint(pos.x, display.height() - pos.y - m_size.height())];
    }
}

void MacWindow::resize(const Size& size)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::resize, this, size));
        return;
    }
    if (size.width() < m_minimumSize.width() || size.height() < m_minimumSize.height())
        return;
    m_size = size;
    m_needsResizeUpdate = true;
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (!window) return;
        NSRect frame = [window frame];
        NSRect content = [window contentRectForFrameRect:frame];
        content.size = NSMakeSize(size.width(), size.height());
        frame = [window frameRectForContentRect:content];
        [window setFrame:frame display:YES];
    }
}

void MacWindow::show()
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::show, this));
        return;
    }
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (!window) return;
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        OTCGLView* view = (__bridge OTCGLView*)m_glView;
        [window makeFirstResponder:view];
        [[view openGLContext] makeCurrentContext];
        m_hidden = false;
        m_visible = true;
        m_focused = true;
        m_needsResizeUpdate = true;
        if (m_maximized)
            maximize();
    }
}

void MacWindow::hide()
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::hide, this));
        return;
    }
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (window)
            [window orderOut:nil];
        m_hidden = true;
        m_visible = false;
    }
}

void MacWindow::minimize()
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::minimize, this));
        return;
    }
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (window)
            [window miniaturize:nil];
    }
}

void MacWindow::maximize()
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::maximize, this));
        return;
    }
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (!window) return;
        // Fill usable screen (not toggle zoom).
        NSRect visible = [[window screen] visibleFrame];
        [window setFrame:visible display:YES];
        m_maximized = true;
        NSView* view = [window contentView];
        NSRect bounds = [view bounds];
        m_size = Size((int)bounds.size.width, (int)bounds.size.height);
        m_needsResizeUpdate = true;
    }
}

void MacWindow::poll()
{
    AutoStat s(STATS_RENDER, "PollWindow");
    @autoreleasepool {
        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                           untilDate:[NSDate distantPast]
                                              inMode:NSDefaultRunLoopMode
                                             dequeue:YES])) {
            [NSApp sendEvent:event];
        }
    }

    if (m_needsResizeUpdate && m_onResize) {
        m_needsResizeUpdate = false;
        m_onResize(m_size);
    }

    g_dispatcher.addEvent([&] {
        fireKeysPress();
        updateUnmaximizedCoords();
    });
}

void MacWindow::swapBuffers()
{
    @autoreleasepool {
        OTCGLView* view = (__bridge OTCGLView*)m_glView;
        if (view)
            [[view openGLContext] flushBuffer];
    }
}

void MacWindow::showMouse()
{
    [NSCursor unhide];
}

void MacWindow::hideMouse()
{
    [NSCursor hide];
}

void MacWindow::setMouseCursor(int cursorId)
{
    if (cursorId >= 0 && cursorId < (int)m_cursors.size()) {
        NSCursor* cursor = (__bridge NSCursor*)m_cursors[cursorId];
        [cursor set];
    }
}

void MacWindow::restoreMouseCursor()
{
    NSCursor* cursor = (__bridge NSCursor*)m_defaultCursor;
    if (cursor)
        [cursor set];
}

void MacWindow::setTitle(const std::string& title)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::setTitle, this, title));
        return;
    }
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (window)
            [window setTitle:[NSString stringWithUTF8String:title.c_str()]];
    }
}

void MacWindow::setMinimumSize(const Size& minimumSize)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::setMinimumSize, this, minimumSize));
        return;
    }
    m_minimumSize = minimumSize;
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (window)
            [window setContentMinSize:NSMakeSize(minimumSize.width(), minimumSize.height())];
    }
}

void MacWindow::setFullscreen(bool fullscreen)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::setFullscreen, this, fullscreen));
        return;
    }
    if (m_fullscreen == fullscreen)
        return;
    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)m_window;
        if (!window) return;
        if (fullscreen != (([window styleMask] & NSWindowStyleMaskFullScreen) != 0))
            [window toggleFullScreen:nil];
        m_fullscreen = fullscreen;
        m_needsResizeUpdate = true;
    }
}

void MacWindow::setVerticalSync(bool enable)
{
    if (std::this_thread::get_id() != g_mainThreadId) {
        g_graphicsDispatcher.addEvent(std::bind(&MacWindow::setVerticalSync, this, enable));
        return;
    }
    m_verticalSync = enable;
    @autoreleasepool {
        OTCGLView* view = (__bridge OTCGLView*)m_glView;
        if (!view) return;
        GLint swap = enable ? 1 : 0;
        [[view openGLContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];
    }
}

void MacWindow::setIcon(const std::string&)
{
    // ponytail: dock icon optional; skip for MVP
}

void MacWindow::setClipboardText(const std::string& text)
{
    @autoreleasepool {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:[NSString stringWithUTF8String:text.c_str()] forType:NSPasteboardTypeString];
    }
}

Size MacWindow::getDisplaySize()
{
    @autoreleasepool {
        // Usable area (excludes menu bar / dock)
        NSRect frame = [[NSScreen mainScreen] visibleFrame];
        return Size((int)frame.size.width, (int)frame.size.height);
    }
}

std::string MacWindow::getClipboardText()
{
    @autoreleasepool {
        NSString* text = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
        if (!text)
            return std::string();
        return std::string([text UTF8String]);
    }
}

std::string MacWindow::getPlatformType()
{
    return "MAC-COCOA";
}

int MacWindow::internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot)
{
    @autoreleasepool {
        int w = image->getWidth();
        int h = image->getHeight();
        const uint8* pixels = image->getPixelData();

        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:nil
                          pixelsWide:w
                          pixelsHigh:h
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSCalibratedRGBColorSpace
                         bytesPerRow:w * 4
                        bitsPerPixel:32];
        memcpy([rep bitmapData], pixels, w * h * 4);
        NSImage* nsimage = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
        [nsimage addRepresentation:rep];
        NSCursor* cursor = [[NSCursor alloc] initWithImage:nsimage hotSpot:NSMakePoint(hotSpot.x, hotSpot.y)];
        m_cursors.push_back((__bridge_retained void*)cursor);
        return (int)m_cursors.size() - 1;
    }
}

void MacWindow::handleResize(int width, int height)
{
    width = std::max(32, std::min(width, 7680));
    height = std::max(32, std::min(height, 4320));
    Size size(width, height);
    if (m_size != size) {
        m_size = size;
        m_needsResizeUpdate = true;
    }
}

void MacWindow::handleClose()
{
    // close() must run on the dispatcher thread
    g_dispatcher.addEvent([this] {
        if (m_onClose)
            m_onClose();
    });
}

void MacWindow::handleFocus(bool focused)
{
    m_focused = focused;
    if (!focused)
        releaseAllKeys();
}

void MacWindow::handleMouseMove(const Point& pos)
{
    int mods = currentKeyboardModifiers();
    Point newPos(std::min(std::max(pos.x, 0), m_size.width()),
                 std::min(std::max(pos.y, 0), m_size.height()));
    newPos = Point(newPos.x / m_scaling, newPos.y / m_scaling);
    g_dispatcher.addEvent([this, mods, newPos] {
        m_inputEvent.reset(Fw::MouseMoveInputEvent);
        m_inputEvent.keyboardModifiers = mods;
        m_inputEvent.mouseMoved = newPos - m_inputEvent.mousePos;
        m_inputEvent.mousePos = newPos;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    });
}

void MacWindow::handleMousePress(Fw::MouseButton button)
{
    int mods = currentKeyboardModifiers();
    g_dispatcher.addEvent([this, mods, button] {
        m_inputEvent.keyboardModifiers = mods;
        m_inputEvent.reset(Fw::MousePressInputEvent);
        m_inputEvent.mouseButton = button;
        m_mouseButtonStates[button] = true;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    });
}

void MacWindow::handleMouseRelease(Fw::MouseButton button)
{
    int mods = currentKeyboardModifiers();
    g_dispatcher.addEvent([this, mods, button] {
        m_inputEvent.keyboardModifiers = mods;
        m_inputEvent.reset(Fw::MouseReleaseInputEvent);
        m_inputEvent.mouseButton = button;
        m_mouseButtonStates[button] = false;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    });
}

void MacWindow::handleMouseWheel(Fw::MouseWheelDirection dir)
{
    int mods = currentKeyboardModifiers();
    g_dispatcher.addEvent([this, mods, dir] {
        m_inputEvent.keyboardModifiers = mods;
        m_inputEvent.reset(Fw::MouseWheelInputEvent);
        m_inputEvent.mouseButton = Fw::MouseMidButton;
        m_inputEvent.wheelDirection = dir;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    });
}

void MacWindow::handleKeyDown(Fw::Key key)
{
    updateModifiers(currentKeyboardModifiers());
    processKeyDown(key);
}

void MacWindow::handleKeyUp(Fw::Key key)
{
    updateModifiers(currentKeyboardModifiers());
    processKeyUp(key);
}

void MacWindow::handleTextInputEvent(const std::string& text)
{
    int mods = currentKeyboardModifiers();
    g_dispatcher.addEvent([this, mods, text] {
        m_inputEvent.keyboardModifiers = mods;
        m_inputEvent.reset(Fw::KeyTextInputEvent);
        m_inputEvent.keyText = text;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    });
}

void MacWindow::updateModifiers(int mods)
{
    m_inputEvent.keyboardModifiers = mods;
}

void MacWindow::releaseKeysOnModifierChange()
{
    releaseAllKeys();
}

#endif // __APPLE__
