# Design System Strategy: CrateBoxd

## 1. Overview & Creative North Star
This design system is built around the Creative North Star of **"The Digital Curator."** 

We are moving away from the "utility-first" look of standard social apps and toward a high-end editorial experience that mirrors the feeling of browsing a physical record store at midnight. The aesthetic is defined by **"Vivid Brutalism"**—where the raw, deep-black canvas of the "crate" meets the high-energy glow of neon discovery. 

By utilizing intentional asymmetry, overlapping card structures, and a typography scale that favors dramatic contrast, we create an environment where the music isn't just listed; it’s showcased. The interface should feel like a premium, tactile object—dense with information yet breathing through sophisticated spatial relationships.

---

## 2. Colors & Tonal Depth

### The Palette
The core of this system is the interplay between the void (`background: #0e0e0e`) and the electric pulse of `primary: #ee2309`. 

*   **Primary (Pulse):** Used for the signature "glow" and high-priority CTAs.
*   **Secondary (Discovery):** `secondary: #3fff8b` provides a refreshing counterpoint, used for success states and growth-oriented actions.
*   **Neutrals (The Crate):** A range of `surface-container` tokens allow us to stack layers without clutter.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders to section off major areas of the UI. Separation must be achieved through:
1.  **Background Shifts:** Placing a `surface-container-low` (`#131313`) card on the main `background` (`#0e0e0e`).
2.  **Vertical Rhythm:** Using the Spacing Scale in `lib/ui/theme/tokens.dart` (`AppSpacing.cardGap` = 12 between cards, `AppSpacing.pageGutter` = 16 at page edges) to create clear, unlined gutters.

### Glassmorphism & Signature Textures
To escape the "flat" look, everything that floats over content (the dock, drawer, sheets, dialogs, menus and toasts) is frosted glass: a **Backdrop Blur** of what's behind it, a tint lighter at the top-left, and a faint light edge. The full rules are in **`docs/glassmorphism.md`**; build it only with `GlassSurface` (`lib/ui/widgets/glass.dart`) and show toasts only with `showAppToast`.
*   **Liquid Glass light (iOS 26 style):** every glass surface carries a rim brightest at the top-left that glints again at the bottom-right, an inner glow under the top edge and a faint sheen (`LiquidRim`). Small controls on black (round buttons, search pills, the dock's sliding selection lens) are `LiquidSurface`: the same light on a faint white fill, no blur.
*   **Panels** (anything with text on it): `surface-container-highest` at about 70% → 48% with a `24px` blur and a little extra saturation.
*   **Tag pills are solid, not glass:** white text on dark grey (`AppColors.pill`, `#2A2A2A`), fully rounded; a selected pill is white with black text (`TagPill`).
*   **Status is an accent, not a fill:** a success / error toast gets a tinted edge and icon, never a solid green or red background.
*   **Gradient Polish:** For main CTAs, use a subtle linear gradient from `primary` (#ff8e80) to `primary-dim` (#e2241f) at a 135-degree angle. This adds a "weighted" feel that flat hex codes lack.


### NOTE
inputs always use borderRadius 25, never 12

---

## 3. Typography: Editorial Authority

We use three fonts, each with a narrow job.

*   **Wordmark (Gasoek One):** The CRATEBOXD logo only, via `GoogleFonts.gasoekOne`, with the custom red outer glow (`drop-shadow: 0 0 12px var(--primary-dim)`).
*   **Display & Headline (Space Grotesk):** Our "loud" voice, via `GoogleFonts.spaceGrotesk`. Bold, wide, and futuristic. Currently used for onboarding headlines.
*   **Body & Title (Google Sans, regular weight):** Our "functional" voice, gentle and easy to read. Set once as the theme's `fontFamily` (`AppFonts.body` in `tokens.dart`), so every text without its own font uses it; never set `fontFamily` per widget. Bundled in `assets/fonts/google_sans/`, trimmed to Latin characters to keep the web download small. It ships in weights 400–700 only (no light weight).

**The Identity Gap:** We create hierarchy not just through size, but through dramatic shifts in tracking and weight. Labels (`label-sm`) should be tracked out by 5-10% to provide an "archival" look, while headlines remain tightly packed for a bold, punchy impact.

---

## 4. Elevation & Layering Principle

Depth is not a drop shadow; depth is a **Tonal Stack.**

*   **The Layering Stack:**
    *   **Base:** `surface-container-lowest` (#000000) for the deepest background.
    *   **Section:** `surface-container-low` (#131313) for large content areas.
    *   **Component:** `surface-container-high` (#201f1f) for cards and interactive modules.
*   **Ambient Shadows:** If a card must "float" (e.g., a modal or a primary button), use an extra-diffused shadow. 
    *   *Spec:* `offset-y: 12px, blur: 24px, color: rgba(0, 0, 0, 0.4)`. 
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline-variant` token at **15% opacity**. It should be felt, not seen.

---

## 5. Signature Components

### Buttons: The Pill
*   **Primary:** Full rounded (`9999px`). High-contrast `on-primary` text on a `primary` background.
*   **Secondary/Ghost:** `outline-variant` border (15% opacity) with `on-surface` text.
*   **Interaction:** On hover, the primary button should increase its "glow" (spread radius of the shadow) rather than just changing color.

### The Crate Card
Music reviews and playlist cards should never use dividers. 
*   **Structure:** Use `surface-container` for the card body. 
*   **Edge Treatment:** `Rounded: 12px` (`AppRadius.card`), with a faint 1px ghost border (white at 15%, `AppColors.ghostBorder`).
*   **Visual Content:** Album art should have a `0.5rem (sm)` corner radius to sit nested within the card's larger radius.

### Navigation: The Floating Dock
The bottom navigation is a pill-shaped "Dock" rather than a screen-wide bar.
*   **Background:** `surface-container-highest` with 80% opacity and `blur`.
*   **Icons:** Clean, 2px stroke icons. The "Add" button is a floating `primary` circle nested within the dock.

---

## 6. Do's and Don'ts

### Do
*   **DO** use `secondary` (#3fff8b) sparingly for "positive" data, such as a high rating or a trending track.
*   **DO** lean into "Breathing Room." If a layout feels crowded, increase spacing to the next tier in the scale (e.g., move from `6` to `8`).
*   **DO** use overlapping imagery. Let album art slightly bleed over the edge of container boundaries to create a sense of physical layers.
*   **DO** use the ionicons package
*   **DO** use the discoball loading gif for loading screens instead of the default spinner, unless it is a small area under 24px 

### Don't
*   **DON'T** use pure white (#ffffff) for secondary text (metadata, timestamps, captions). Use `on-surface-variant` (#adaaaa). Titles and long-form review text stay white.
*   **DON'T** use 100% opaque borders. They break the "Neon Archive" immersion.
*   **DON'T** use standard "Material" ripple effects. Prefer subtle scale-downs (98%) or opacity shifts for active states to maintain a premium feel.
*.  **DON't** use standard loading spinner, loading gifs, loading cards, UNLESS, the area is small - use the discoball.loading.gif for most - if the area is too small, then use the loading circle spinner