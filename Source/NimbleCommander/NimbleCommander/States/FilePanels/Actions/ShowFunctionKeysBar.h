// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// Relies on global config: the function keys bar is shown in every file-panels window or in none.
struct ShowFunctionKeysBar final : StateAction {
    [[nodiscard]] bool ValidateMenuItem(MainWindowFilePanelState *_target, NSMenuItem *_item) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

} // namespace nc::panel::actions
