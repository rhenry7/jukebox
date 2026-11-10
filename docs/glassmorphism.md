# Glassmorphism

Anything that floats over the app's content is frosted glass: the dock, the
drawer, sheets, dialogs, menus and toasts. The content behind it
(album art, the feed) shows through, blurred, so the app feels like one layered
object rather than a stack of grey boxes.

There is **one recipe**, in **one widget**: `GlassSurface`
(`lib/ui/widgets/glass.dart`), with its numbers in `AppGlass`
(`lib/ui/theme/tokens.dart`). Never build glass by hand.
`test/glass/glass_guard_test.dart` fails if any other file uses
`BackdropFilter` / `ImageFilter.blur`, or shows a toast without `showAppToast`.

## The recipe

Every glass surface has the same four layers, from back to front:

1. **Blur** of what's behind it (`BackdropFilter`). Panels also raise its
   saturation slightly (1.3), so colors glow through instead of turning grey.
2. **Tint**: a diagonal gradient, lighter at the top-left where light hits
   it and fading toward the bottom-right.
3. **Edge**: a faint 1px light border, so the shape reads against busy art.
   It is felt, not seen (see the "Ghost Border" in `design_system.md`).
4. **Content** on top: white text (`AppColors.onSurface`), with
   `onSurfaceVariant` for secondary text.

## Strength

| Use for | Blur | Tint | Edge |
|---|---|---|---|
| Dock, drawer, sheets, dialogs, menus, toasts | 24 + saturation | dark (`surfaceContainerHighest`) ≈ 70% → 48% | white 18% |

The dark tint keeps text readable over bright album art.

**Tag pills are not glass.** They're solid dark grey (`AppColors.pill`,
#2A2A2A) with white text, and white with black text when selected: `TagPill`
in `lib/ui/widgets/genre_pills.dart`. The Home sort button next to them
matches. Small, repeated items read better solid, and dozens of live blurs
cost too much on phones.

## Rules

- **Shape comes from the radius tokens.** The dock uses
  `AppRadius.pillAll`; menus, toasts and small tiles use `AppRadius.cardAll`
  (12); dialogs, sheets and the drawer use `AppRadius.xl` (24).
- **Shadow only when it floats over content** (`shadow: true`): the dock,
  dialogs and dropdown menus. It uses `AppShadows.ambient` and is drawn
  outside the clip. Sheets and toasts don't need one.
- **Color is an accent, never a fill.** Status shows as a tinted edge
  (`accent:`) and an icon, not a solid green or red background.
- **Give the glass something to blur.** Barriers behind glass dialogs and
  sheets are light (`Colors.black26`–`black38`), not the default heavy dim,
  or the glass just looks grey.
- **Nothing repeated is glass.** Anything that appears many times on screen
  (tag pills, list rows) is solid; glass is for the few things floating
  above content.
- **Never put glass on glass on glass.** One glass layer over content is the
  look; a pill inside a glass sheet is fine, but don't nest panels.
- **Card backgrounds aren't glass.** Review cards use a pre-blurred image
  (`CardSurface`), not a live blur: a live blur per card is too slow while
  scrolling on phones.
- **No Material defaults that paint over the glass.** `Chip`, `Card` and
  `SnackBar` paint opaque theme backgrounds; set them transparent or use the
  shared widgets.

## Toasts

Show every toast with `showAppToast` (`lib/ui/widgets/app_toast.dart`):

```dart
showAppToast(context, 'Review deleted', tone: ToastTone.success);

// After an await, with the messenger saved before the gap:
final messenger = ScaffoldMessenger.of(context);
await doSomething();
messenger.showAppToast("Couldn't delete the review. Try again.",
    tone: ToastTone.error);
```

- A toast is a glass **panel** floating above the dock, inset 16 from the
  screen edges, with radius 12. It stays 3 seconds by default, and tapping
  it dismisses it.
- A new toast replaces the one showing instead of queueing behind it.
- `tone` picks the icon and edge color: `info` (none, the default),
  `success` (green check), `warning` (amber), `error` (red).
- Write messages for people: "Couldn't post your comment. Try again.", never
  `Error: $e`. Log the exception with `debugPrint` instead. Auth errors go
  through `authErrorMessage(code)`.

## Where it's used

| Surface | File |
|---|---|
| Nav dock | `lib/routing/MainNavigation.dart` (`_GlassDock`) |
| Drawer | `lib/routing/MainNavigation.dart` (`_AppDrawer`) |
| Dialogs | `lib/ui/widgets/glass_dialog.dart` (`GlassDialog`) |
| Reviewer sheet | `lib/ui/widgets/review_card.dart` |
| Comments sheet | `lib/ui/widgets/review_comments.dart` |
| Home sort button and menu | `lib/ui/widgets/home_feed_controls.dart` |
| Toasts | `lib/ui/widgets/app_toast.dart` |

## Performance

A live blur is one of the most expensive things to draw. Keep glass to
surfaces that float (a handful on screen), group repeated ones, and never
put a live blur inside a scrolling list item. Check new glass on a real
phone, especially an older iPhone, while scrolling.
