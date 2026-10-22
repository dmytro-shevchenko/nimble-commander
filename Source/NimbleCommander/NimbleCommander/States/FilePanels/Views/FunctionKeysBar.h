// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/ActionsShortcutsManager.h>
#include <Cocoa/Cocoa.h>

// Row of standard push buttons along the bottom of the file-panels window.
// Each button shows the action name and the hotkey currently assigned to it.
@interface NCFunctionKeysBar : NSView

- (instancetype)initWithFrame:(NSRect)frameRect
      actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager;

@property(class, nonatomic, readonly) CGFloat preferredHeight;

@end
