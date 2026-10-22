// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FunctionKeysBar.h"
#include "../PanelControllerActionsDispatcher.h"
#include "../StateActionsDispatcher.h"
#include <Config/Config.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Utility/ObjCpp.h>
#include <array>
#include <vector>

static const int g_SlotCount = 9;
static const CGFloat g_VerticalPadding = 8.;
static const auto g_HotkeyOverridesPath = "hotkeyOverrides_v1";

struct FunctionKeySlot {
    const char *action;
    SEL selector;
};

static const std::array<FunctionKeySlot, g_SlotCount> g_Slots = {{
    {"menu.go.left_panel", @selector(onLeftPanelGoToButtonAction:)},
    {"menu.go.right_panel", @selector(onRightPanelGoToButtonAction:)},
    {"menu.command.internal_viewer", @selector(OnFileInternalBigViewCommand:)},
    {"menu.command.external_editor", @selector(OnOpenWithExternalEditor:)},
    {"menu.command.copy_to", @selector(OnFileCopyCommand:)},
    {"menu.command.move_to", @selector(OnFileRenameMoveCommand:)},
    {"menu.command.create_directory", @selector(OnCreateDirectoryCommand:)},
    {"menu.command.delete", @selector(OnDeleteCommand:)},
    {"menu.command.compress_here", @selector(onCompressItemsHere:)},
}};

static NSString *TitleForSlot(int _index)
{
    switch( _index ) {
        case 0:
            return NSLocalizedString(@"Left", "Function keys bar button for the left panel");
        case 1:
            return NSLocalizedString(@"Right", "Function keys bar button for the right panel");
        case 2:
            return NSLocalizedString(@"View", "Function keys bar button for the internal viewer");
        case 3:
            return NSLocalizedString(@"Edit", "Function keys bar button for the external editor");
        case 4:
            return NSLocalizedString(@"Copy", "Function keys bar button for copy");
        case 5:
            return NSLocalizedString(@"Move", "Function keys bar button for move");
        case 6:
            return NSLocalizedString(@"MkDir", "Function keys bar button for creating a directory");
        case 7:
            return NSLocalizedString(@"Delete", "Function keys bar button for delete");
        case 8:
            return NSLocalizedString(@"Compress", "Function keys bar button for compress");
        default:
            return @"";
    }
}

static NSString *ButtonTitle(NSString *_hotkey, NSString *_title)
{
    if( _hotkey.length > 0 )
        return [NSString stringWithFormat:@"%@ %@", _hotkey, _title];
    return _title;
}

static NSButton *MakePushButton(SEL _action)
{
    NSButton *const button = [NSButton buttonWithTitle:@"" target:nil action:_action];
    button.bezelStyle = NSBezelStyleRounded;
    button.buttonType = NSButtonTypeMomentaryPushIn;
    button.refusesFirstResponder = true;
    button.lineBreakMode = NSLineBreakByTruncatingTail;
    button.translatesAutoresizingMaskIntoConstraints = false;
    [button setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    return button;
}

@implementation NCFunctionKeysBar {
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
    NSString *m_Titles[g_SlotCount];
    NSButton *m_Buttons[g_SlotCount];
    NSStackView *m_Stack;
    std::vector<nc::config::Token> m_ConfigTickets;
}

+ (CGFloat)preferredHeight
{
    static const CGFloat height = [] {
        NSButton *const probe = MakePushButton(nil);
        probe.title = @"F1 Left";
        return ceil(probe.intrinsicContentSize.height) + g_VerticalPadding;
    }();
    return height;
}

- (instancetype)initWithFrame:(NSRect)frameRect
      actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;
        for( int i = 0; i < g_SlotCount; ++i ) {
            m_Titles[i] = TitleForSlot(i);
            m_Buttons[i] = MakePushButton(g_Slots[i].selector);
        }

        m_Stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        m_Stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        m_Stack.distribution = NSStackViewDistributionFillEqually;
        m_Stack.alignment = NSLayoutAttributeCenterY;
        m_Stack.spacing = 6.;
        m_Stack.edgeInsets = NSEdgeInsetsMake(4., 8., 4., 8.);
        m_Stack.translatesAutoresizingMaskIntoConstraints = false;
        for( int i = 0; i < g_SlotCount; ++i )
            [m_Stack addArrangedSubview:m_Buttons[i]];
        [self addSubview:m_Stack];

        [NSLayoutConstraint activateConstraints:@[
            [m_Stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [m_Stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [m_Stack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [m_Stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        [self reloadHotkeys];
        m_ConfigTickets.emplace_back(
            GlobalConfig().Observe(g_HotkeyOverridesPath, nc::objc_callback(self, @selector(reloadHotkeys))));
    }
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (void)reloadHotkeys
{
    for( int i = 0; i < g_SlotCount; ++i ) {
        NSString *hotkey = @"";
        if( const auto shortcuts = m_ActionsShortcutsManager->ShortcutsFromAction(g_Slots[i].action) )
            if( !shortcuts->empty() )
                hotkey = shortcuts->front().PrettyString();
        NSString *const title = ButtonTitle(hotkey, m_Titles[i]);
        m_Buttons[i].title = title;
        m_Buttons[i].toolTip = title;
    }
}

@end
