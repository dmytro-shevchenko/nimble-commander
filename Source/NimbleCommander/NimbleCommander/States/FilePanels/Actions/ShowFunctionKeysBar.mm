// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowFunctionKeysBar.h"
#include <NimbleCommander/Bootstrap/Config.h>

namespace nc::panel::actions {

static const auto g_ConfigShowFunctionKeysBar = "general.showFunctionKeysBar";
static const auto g_ShowTitle =
    NSLocalizedString(@"Show Function Keys Bar", "Menu item title for showing the function keys bar");
static const auto g_HideTitle =
    NSLocalizedString(@"Hide Function Keys Bar", "Menu item title for hiding the function keys bar");

bool ShowFunctionKeysBar::ValidateMenuItem(MainWindowFilePanelState *_target, NSMenuItem *_item) const
{
    _item.title = GlobalConfig().GetBool(g_ConfigShowFunctionKeysBar) ? g_HideTitle : g_ShowTitle;
    return Predicate(_target);
}

void ShowFunctionKeysBar::Perform([[maybe_unused]] MainWindowFilePanelState *_target, id /*_sender*/) const
{
    const auto shown = GlobalConfig().GetBool(g_ConfigShowFunctionKeysBar);
    GlobalConfig().Set(g_ConfigShowFunctionKeysBar, !shown);
}

} // namespace nc::panel::actions
