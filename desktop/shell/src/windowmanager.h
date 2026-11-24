// Enclave Shell — the window-management contract.
// Surfaces (taskbar, bubble, switcher) talk to this interface, never to a
// particular compositor. The first implementation is ToplevelModel
// (wlr-foreign-toplevel-management, provided by wlroots-based
// compositors); swapping the compositor means adding another implementation.
#pragma once
#include <QString>

class WindowManager {
public:
    virtual ~WindowManager() = default;
    virtual int windowCount() const = 0;
    virtual void activate(int index) = 0;
    virtual void minimize(int index) = 0;
    virtual void toggleMaximize(int index) = 0;
    virtual void close(int index) = 0;
    virtual int activeIndex() const = 0;
    virtual bool available() const = 0;   // compositor offers window management
};
