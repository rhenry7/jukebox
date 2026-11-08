import 'package:flutter/material.dart';

/// Design tokens for CrateBoxd — the code form of `design_system.md`.
///
/// Screens and widgets should use these instead of raw numbers / hex codes so
/// spacing, corners and colors stay consistent across the app.
///
/// See docs/ui_audit/token_mapping.md for the raw-value → token migration
/// mapping.

/// Fonts. [body] is the app-wide default (set on every ThemeData in
/// main.dart); headlines use Space Grotesk and the wordmark Gasoek One via
/// google_fonts.
abstract final class AppFonts {
  static const String body = 'Google Sans';
}

/// Spacing scale (4pt base). Use for EdgeInsets, SizedBox, Gap, etc.
///
/// When a layout feels crowded, step up to the next tier rather than
/// inventing an in-between value ("Breathing Room" rule).
abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Horizontal page gutter for scrollable screens.
  static const double pageGutter = lg;

  /// Inner padding of a Crate Card (review / playlist / album cards).
  static const double cardPadding = xl;

  /// Gap between stacked cards in a list, and their inset from the screen
  /// edges: a slight frame so each card reads as its own rounded tile.
  static const double cardGap = sm;

  /// Bottom padding for scrollable content under the floating nav dock
  /// (dock 72 + bottom inset 12, plus a gutter so the last card clears it).
  static const double dockClearance = 112;

  /// Padding around each card in a vertical card list: [cardGap] in from the
  /// screen edges and [cardGap] between cards.
  static const EdgeInsets cardListItem = EdgeInsets.symmetric(
    horizontal: cardGap,
    vertical: cardGap / 2,
  );
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double none = 0;
  static const double xs = 4;

  /// Album art nested inside a card.
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Bottom sheets and large modals.
  static const double xl = 24;

  /// Crate Card edge (review / playlist / album cards): slightly rounded.
  static const double card = md;

  /// Text inputs — always 25, never 12.
  static const double input = 25;

  /// Pills: primary buttons, chips, the floating dock.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputAll = BorderRadius.all(Radius.circular(input));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Color palette. Surfaces form a tonal stack — separate areas by stepping
/// surface level, not with 1px borders.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFEE2309);
  static const Color primaryLight = Color(0xFFFF8E80);
  static const Color primaryDim = Color(0xFFE2241F);
  static const Color secondary = Color(0xFF3FFF8B);

  // Surfaces (lowest → highest)
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color background = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1A1919);
  static const Color surfaceContainerHigh = Color(0xFF201F1F);
  static const Color surfaceContainerHighest = Color(0xFF262626);

  // Content
  /// Titles and body text (including long-form review text).
  static const Color onSurface = Color(0xFFFFFFFF);

  /// Secondary text: metadata, timestamps, captions.
  static const Color onSurfaceVariant = Color(0xFFADAAAA);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color outlineVariant = Color(0xFF494847);

  /// Faint 1px card outline ("Ghost Border") — white at 15%.
  static const Color ghostBorder = Color(0x26FFFFFF);

  // Status
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = secondary;

  /// Star ratings.
  static const Color rating = Color(0xFFFFC107);
}

/// Elevation — depth comes from the tonal stack; shadows only for floating
/// elements (modals, primary buttons).
abstract final class AppShadows {
  static const List<BoxShadow> ambient = [
    BoxShadow(offset: Offset(0, 12), blurRadius: 24, color: Color(0x66000000)),
  ];

  /// Backdrop blur sigma for glass panels. Same as [AppGlass.panelBlur].
  static const double glassBlur = AppGlass.panelBlur;
}

/// Glassmorphism: the numbers behind every frosted surface. See
/// docs/glassmorphism.md for the rules; build glass with `GlassSurface`
/// (lib/ui/widgets/glass.dart), never by hand.
abstract final class AppGlass {
  /// Pills and small controls: a light blur and a clear white tint, so the
  /// album art or page behind them shows through.
  static const double pillBlur = 8;
  static const Color pillTintLit = Color(0x29FFFFFF); // white 16%
  static const Color pillTintFar = Color(0x0DFFFFFF); // white 5%
  static const Color pillEdge = Color(0x40FFFFFF); // white 25%

  /// Panels (dock, drawer, sheets, dialogs, menus, toasts): a heavy blur and
  /// a dark tint, so text on them stays readable over anything.
  static const double panelBlur = 24;

  /// The panel tint, lighter at the top-left where the light hits.
  static const Color panelTintLit = Color(
    0xB3363636,
  ); // ≈ highest 62% + white 8%
  static const Color panelTintFar = Color(0x7A262626); // highest 48%
  static const Color panelEdge = Color(0x2EFFFFFF); // white 18%

  /// How much an accent (a toast's success / error color) tints the edge.
  static const double accentEdgeOpacity = 0.55;

  /// Saturation 1.3 behind panels, so colors glow through the blur instead
  /// of turning grey.
  static const List<double> saturate = [
    1.2364, -0.2145, -0.0219, 0, 0, //
    -0.0636, 1.0855, -0.0219, 0, 0,
    -0.0636, -0.2145, 1.2781, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
