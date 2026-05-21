# Design System Specification

## 1. Overview & Creative North Star: "Industrial Precisionism"

This design system is a sophisticated dialogue between the tactile nostalgia of legacy computing and the high-density functionalism of modern digital workstations. Our Creative North Star is **The Machinist’s Manuscript**: a visual language that feels as intentional as a technical blueprint and as prestigious as a high-end editorial.

By merging the rigid, beveled architecture of Windows 95 with the modular, information-dense layout of Ableton Live, we move away from the "generic web" look. We reject soft corners and organic flows in favor of hard edges, high-contrast tonal layering, and an aggressive commitment to a 0px border-radius. The result is a premium, authoritative experience that feels engineered rather than merely "designed."

---

## 2. Colors & Chromatic Rigor

The palette is anchored by a vibrant, saturated Gold that commands attention without feeling "muddy." This is supported by warm, gallery-grade neutrals that provide a clean stage for high-density data.

### Primary Palette
- **The Signature Gold:** Use `primary_container` (#ffb800) for high-impact moments. This is our "Active" state—vibrant, saturated, and intentional. Use `primary` (#7c5800) for text-based hierarchy and `primary_fixed` (#ffdea8) for subtle highlights.
- **Accent Logic:** Use `secondary` (#b02d28 - Red) for critical errors or destructive actions. Use `tertiary` (#005bbe - Blue) for systemic information and secondary interactive paths. These must remain accents; they are the "wires" in the machine.

### The "No-Line" Rule & Surface Hierarchy
- **No 1px Borders for Sectioning:** Traditional 1px solid borders are prohibited for layout division. Instead, define space through background shifts.
- **Tonal Nesting:** Treat the UI as a series of machined plates. A `surface` (#fbf9f2) base should host `surface_container_low` (#f6f4ec) modules, which in turn house `surface_container_high` (#eae8e1) interactive components. This "nested" depth creates a physical sense of hierarchy.
- **Signature Texture:** Main CTAs should utilize a subtle vertical gradient transitioning from `primary_container` (#ffb800) to `primary` (#7c5800). This mimics the metallic sheen of industrial hardware.

---

## 3. Typography: The Editorial Blueprint

We utilize a high-contrast typographic pairing to balance technical utility with editorial prestige.

- **Headlines (Display & Headline Scales):** `Space Grotesk`. This typeface’s technical apertures and geometric construction reinforce the industrial theme. Use `headline-lg` (2rem) for section headers to create an authoritative, "monumental" feel.
- **Functional Text (Title, Body, Label Scales):** `Inter`. Chosen for its supreme legibility at small sizes. In high-density Ableton-style modules, use `label-md` (0.75rem) for data points to maximize information density without sacrificing clarity.
- **Editorial Intent:** Maintain wide tracking for uppercase labels and tight leading for large display headers. Typography should feel like it was typeset for a technical manual, yet balanced with the elegance of a luxury magazine.

---

## 4. Elevation & Depth: The Beveled Architecture

In this design system, depth is not achieved through light and shadow, but through **Tonal Layering** and **Structural Bevels**.

- **The Win95 Bevel:** All interactive elements (Buttons, Inputs, Cards) must utilize a 2px "Machined Bevel." 
    - **Raised State:** Top/Left edges use `surface_container_lowest` (#ffffff); Bottom/Right edges use `outline_variant` (#d5c4ab).
    - **Sunken State (Active/Input):** Reverses the bevel colors to create a "pressed" effect.
- **Ambient Shadows:** Standard drop shadows are forbidden. When a "floating" element (like a modal) is required, use an extra-diffused 8% opacity shadow tinted with `on_surface` (#1b1c18) to simulate ambient laboratory lighting.
- **Glassmorphism Integration:** For floating overlays or tooltips, use `surface_container_low` at 85% opacity with a `20px` backdrop blur. This allows the saturated Gold and modular background to bleed through, preventing the UI from feeling "heavy" or "cluttered."

---

## 5. Components

### Buttons & Inputs
- **Primary Button:** `primary_container` (#ffb800) background with a 2px "Raised" bevel. Typography set to `label-md` in `on_primary_container` (#6b4c00), all-caps with 0.05em tracking.
- **Text Inputs:** `surface_container_lowest` (#ffffff) background with a "Sunken" bevel. Label text uses `label-sm` in `outline` (#837560).

### Ableton-Style Modular Trays
- **Container:** Modules must be grouped in `surface_container_high` (#eae8e1) blocks. 
- **Separation:** Use vertical white space (`spacing-8` or `spacing-10`) instead of divider lines. 
- **Density:** Leverage the `0.2rem` (spacing-1) scale for internal module padding to achieve a professional, tool-like density.

### Chips & Status Indicators
- Use `tertiary_container` (#a9c5ff) for status chips. They should be rectangular (0px radius) and utilize the "Ghost Border" (10% opacity `outline-variant`) to sit softly against the background.

---

## 6. Do’s and Don’ts

### Do:
- **Do** use `0px` roundedness for everything. Precision is key.
- **Do** leverage the `surface-container` tiers to create a "tabbed" or "modular" look typical of industrial software.
- **Do** allow the Gold (`primary_container`) to be the "hero" of the layout; use it sparingly but boldly to guide the user's eye.
- **Do** use the "Ghost Border" fallback (10-20% opacity) if a visual container needs extra definition on a complex background.

### Don't:
- **Don’t** use standard 1px black or grey borders. They break the high-end editorial feel.
- **Don’t** use soft, rounded corners. This system is built on a "Machined Edge" philosophy.
- **Don’t** use gradients that move into brown or muddy territory. Ensure all transitions stay within the vibrant, saturated yellow-gold spectrum.
- **Don’t** use dividers or lines to separate list items; use tonal shifts between `surface_container_low` and `surface_container_high`.

---

## 7. Spacing & Grid Logic

The layout should follow a strict modular grid inspired by rack-mounted hardware.
- **The "Modular Gap":** Use `spacing-2.5` (0.5rem) as the standard gap between small interface components.
- **The "Section Break":** Use `spacing-16` (3.5rem) to separate major functional blocks.
- **Asymmetry:** Challenge the grid by offsetting large display type against high-density data modules. This intentional imbalance is what elevates the system from a "template" to a "signature experience."