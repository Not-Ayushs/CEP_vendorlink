# Design System Specification: Precision Utility

## 1. Overview & Creative North Star
**The Creative North Star: "The Digital Sanctuary of Logic"**

In the rugged, high-stakes environment of solid waste management, the interface must serve as a calm, authoritative counterpoint to the physical chaos of the field. This design system rejects the cluttered "dashboard-itis" of enterprise software in favor of **Precision Minimalism**. 

We move beyond standard templates by treating the UI as an editorial layout—utilizing intentional asymmetry, aggressive white space, and high-contrast typography to ensure that a field worker standing in direct sunlight can make a split-second decision with total confidence. The aesthetic is "High-End Industrial": it feels like a premium tool, not just another app.

---

## 2. Color & Surface Architecture
We utilize a sophisticated palette that prioritizes legibility and professional trust. Our primary emerald (`#006948`) and secondary deep blue (`#3755c3`) are the anchors of reliability.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders to define sections or containers. 
Boundaries must be created through **Tonal Transitions**. A section shift is indicated by moving from `surface` (#f7f9fb) to `surface-container-low` (#f2f4f6). This creates a seamless, modern flow that prevents the "grid-trapped" feeling of legacy software.

### Surface Hierarchy & Nesting
Treat the UI as a series of layered, physical materials.
*   **Base:** `background` (#f7f9fb)
*   **The Content Layer:** `surface_container_lowest` (#ffffff) — Reserved for the primary focus area.
*   **The Utility Layer:** `surface_container` (#eceef0) — Used for secondary tools or sidebars.

### The "Glass & Gradient" Rule
To elevate the experience from "utility" to "premium," floating elements (like mobile navigation bars or quick-action FABs) should utilize **Glassmorphism**. Use `surface_container_highest` at 80% opacity with a `24px` backdrop blur. 
*   **Signature Textures:** For high-level CTA buttons, use a subtle linear gradient from `primary` (#006948) to `primary_container` (#00855d) at a 135-degree angle. This adds "soul" and depth to the interaction points.

---

## 3. Typography: The Editorial Scale
We use **Inter** as our sole typeface. The power of this system lies in the contrast between technical metadata and bold headlines.

*   **Display & Headline:** Use `display-sm` (2.25rem) for critical daily stats (e.g., "42 Tons Collected"). It should feel authoritative and unmissable.
*   **The Meta-Data Tier:** Use `label-md` (0.75rem) for technical details like GPS coordinates or vehicle IDs. 
*   **The Narrative Tier:** `body-lg` (1rem) is the workhorse. Ensure a line height of at least 1.5 to maintain breathability.

**Hierarchy Strategy:** Never use weight alone to show importance. Use scale and color. A `title-sm` in `primary` is often more effective than a bold black title for guiding the eye toward "next steps."

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are largely replaced by **Ambient Depth**.

*   **The Layering Principle:** Instead of a shadow, place a `surface_container_lowest` card on a `surface_container_low` background. The subtle shift in hex code creates a "soft lift" that feels integrated into the environment.
*   **Ambient Shadows:** If a floating state is required (e.g., a modal), use an ultra-diffused shadow:
    *   `Y: 12px, Blur: 32px, Color: on_surface @ 6% opacity`.
*   **The "Ghost Border" Fallback:** If a container requires definition against an identical background, use a **Ghost Border**: `outline_variant` at 15% opacity. Never use 100% opaque outlines.

---

## 5. Components: The Primitive Set

### Buttons (Tactile Reliability)
Field workers need targets they can hit while moving.
*   **Primary:** `xl` (1.5rem / 24px) corner radius. Height: 56px minimum for mobile. Use the Signature Gradient.
*   **Secondary:** Ghost style with `outline_variant` at 20% opacity. No fill.

### The "Field Card" (Mobile First)
*   **Style:** No borders. `lg` (1rem) corner radius. 
*   **Separation:** Prohibit divider lines. Use `16px` or `24px` of vertical white space to separate list items.
*   **Interaction:** Large touch targets for "Swipe to Confirm" or "Add Photo" actions.

### Chips (Fluid Filtering)
*   **Action Chips:** Pill-shaped (`full` roundedness). Use `surface_container_high` for inactive and `primary` for active states.
*   **Status Chips:** Use `error_container` or `primary_fixed` with high-contrast text (`on_error_container` or `on_primary_fixed`) for immediate status recognition in sunlight.

### Input Fields
*   **Anatomy:** Floating labels using `label-md`. Background: `surface_container_low`. 
*   **State:** On focus, the border doesn't just change color; the container shifts to `surface_container_lowest` to "push" the field toward the user.

---

## 6. Do’s and Don’ts

### Do:
*   **Embrace Asymmetry:** In the Admin Desktop view, allow the primary data visualization to take up 70% of the screen while the sidebar floats with generous margins.
*   **Prioritize Thumb-Zones:** Keep all critical "Waste Ops" actions (Clock-in, Route Start, Emergency) in the bottom third of the mobile screen.
*   **Use High Contrast:** Ensure all text on `background` meets a minimum 4.5:1 ratio for outdoor legibility.

### Don't:
*   **Don't Box Everything:** Avoid the "Russian Doll" effect of putting cards inside of cards. Use white space and tonal shifts instead.
*   **Don't Use Pure Black:** Use `on_surface` (#191c1e) for text. Pure black is too harsh and reduces the "premium" feel.
*   **Don't Use 1px Dividers:** They create visual "noise" that tires the eye during long shifts. If you think you need a line, you actually need more padding.

---

## 7. Signature Detail: The "Eco-Pulse"
Whenever an action is completed (e.g., a bin is marked as collected), use a subtle micro-interaction: a gentle expansion of the `primary_fixed` color that fades into the background. This provides the "Reliable & Efficient" brand feedback without requiring intrusive pop-up modals.
