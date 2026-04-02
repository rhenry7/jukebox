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
2.  **Vertical Rhythm:** Using the Spacing Scale (specifically `8` and `10` tokens) to create clear, unlined gutters.

### Glassmorphism & Signature Textures
To escape the "flat" look, floating elements (like the navigation bar or "Now Playing" widgets) must utilize **Backdrop Blur**. 
*   **Surface:** Use `surface-container-highest` at 70% opacity with a `24px` blur.
*   **Gradient Polish:** For main CTAs, use a subtle linear gradient from `primary` (#ff8e80) to `primary-dim` (#e2241f) at a 135-degree angle. This adds a "weighted" feel that flat hex codes lack.


### NOTE
inputs always use borderRadius 25, never 12

---

## 3. Typography: Editorial Authority

We use a dual-font strategy to balance character with readability.

*   **Display & Headline (Space Grotesk):** This is our "loud" voice. Bold, wide, and futuristic. Use `display-lg` for the signature logo style with a custom outer glow (`drop-shadow: 0 0 12px var(--primary-dim)`).
*   **Body & Title (Manrope):** Our "functional" voice. Manrope provides a clean, geometric stability that ensures long-form music reviews remain legible even on a pitch-black background.

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
*   **Edge Treatment:** `Rounded: 1.5rem (md)`.
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

### Don't
*   **DON'T** use pure white (#ffffff) for long-form body text. Use `on-surface-variant` (#adaaaa) to reduce eye strain on dark backgrounds.
*   **DON'T** use 100% opaque borders. They break the "Neon Archive" immersion.
*   **DON'T** use standard "Material" ripple effects. Prefer subtle scale-downs (98%) or opacity shifts for active states to maintain a premium feel.