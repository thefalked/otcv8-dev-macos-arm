/*
 * Native Cocoa / NSOpenGL window backend for macOS (no XQuartz).
 */

#ifndef MACWINDOW_H
#define MACWINDOW_H

#include "platformwindow.h"

class MacWindow : public PlatformWindow
{
public:
    MacWindow();

    void init() override;
    void terminate() override;

    void move(const Point& pos) override;
    void resize(const Size& size) override;
    void show() override;
    void hide() override;
    void minimize() override;
    void maximize() override;
    void poll() override;
    void swapBuffers() override;
    void showMouse() override;
    void hideMouse() override;

    void setMouseCursor(int cursorId) override;
    void restoreMouseCursor() override;

    void setTitle(const std::string& title) override;
    void setMinimumSize(const Size& minimumSize) override;
    void setFullscreen(bool fullscreen) override;
    void setVerticalSync(bool enable) override;
    void setIcon(const std::string& file) override;
    void setClipboardText(const std::string& text) override;

    Size getDisplaySize() override;
    std::string getClipboardText() override;
    std::string getPlatformType() override;

    // Called from ObjC view / window delegate
    void handleResize(int width, int height);
    void handleClose();
    void handleFocus(bool focused);
    void handleMouseMove(const Point& pos);
    void handleMousePress(Fw::MouseButton button);
    void handleMouseRelease(Fw::MouseButton button);
    void handleMouseWheel(Fw::MouseWheelDirection dir);
    void handleKeyDown(Fw::Key key);
    void handleKeyUp(Fw::Key key);
    void handleTextInputEvent(const std::string& text);
    void updateModifiers(int mods);
    void releaseKeysOnModifierChange();


protected:
    int internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot) override;

private:
    void* m_window = nullptr;      // NSWindow*
    void* m_glView = nullptr;      // NSOpenGLView*
    void* m_appDelegate = nullptr; // OTCAppDelegate*
    void* m_defaultCursor = nullptr;
    std::vector<void*> m_cursors;  // NSCursor*
    bool m_hidden = true;
    bool m_needsResizeUpdate = false;
};

#endif
