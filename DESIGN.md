---
name: Clinical Precision
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#424752'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#727783'
  outline-variant: '#c2c6d4'
  surface-tint: '#005db6'
  primary: '#00478d'
  on-primary: '#ffffff'
  primary-container: '#005eb8'
  on-primary-container: '#c8daff'
  inverse-primary: '#a9c7ff'
  secondary: '#575f67'
  on-secondary: '#ffffff'
  secondary-container: '#d8e1ea'
  on-secondary-container: '#5b646b'
  tertiary: '#005055'
  on-tertiary: '#ffffff'
  tertiary-container: '#006a71'
  on-tertiary-container: '#73ecf6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#a9c7ff'
  on-primary-fixed: '#001b3d'
  on-primary-fixed-variant: '#00468c'
  secondary-fixed: '#dbe4ed'
  secondary-fixed-dim: '#bfc8d0'
  on-secondary-fixed: '#141d23'
  on-secondary-fixed-variant: '#3f484f'
  tertiary-fixed: '#7df4ff'
  tertiary-fixed-dim: '#5dd8e2'
  on-tertiary-fixed: '#002022'
  on-tertiary-fixed-variant: '#004f54'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
  max-width: 1440px
---

## Brand & Style
The brand personality is authoritative, sterile, and technologically advanced. This design system targets dental professionals and clinic procurement officers who prioritize reliability, hygiene, and precision. The visual direction follows a **Corporate / Modern** aesthetic with a lean toward **Minimalism**, ensuring that complex medical specifications remain legible and organized. The emotional response should be one of absolute trust and professional "cleanliness," mimicking the high-end environment of a modern dental laboratory. High-density information is balanced with generous whitespace to prevent cognitive overload during procurement workflows.

## Colors
The palette is rooted in medical professionalism. The primary **Medical Blue (#005EB8)** is used for primary actions, critical branding, and highlighting essential data points. A secondary **Teal (#00A3AD)** is reserved for success states, health-related indicators, or interactive subtle accents. The background architecture relies on a "Laboratory White" and various shades of light gray to create a sterile, high-contrast environment. Darker grays are utilized exclusively for text to ensure AAA accessibility. Surface colors are strictly white to maintain a clinical feel.

## Typography
This design system utilizes **Inter** for its systematic, utilitarian nature and exceptional legibility at small sizes—crucial for technical dental specifications. Headlines use a semi-bold weight with tight letter spacing for a controlled, authoritative look. Body copy is set with generous line-height to ensure readability of long-form clinical documentation. Labels use uppercase styling and increased letter-spacing to clearly differentiate metadata from narrative content.

## Layout & Spacing
The layout follows a **Fixed Grid** model on desktop (12 columns) and a fluid 4-column model on mobile. A strict 4px baseline grid ensures technical precision in component alignment. 
- **Desktop:** 12 columns, 24px gutters, and 64px outside margins.
- **Tablet:** 8 columns, 24px gutters, and 32px outside margins.
- **Mobile:** 4 columns, 16px gutters, and 16px outside margins.
Vertical rhythm is maintained using 24px increments (md) to separate logical sections of a product page, while 8px (xs) is used for tight groupings of related inputs or technical specs.

## Elevation & Depth
Depth is communicated through **Tonal Layers** and **Low-Contrast Outlines**. In a clinical interface, excessive shadows can feel "muddy." This design system uses a primary method of 1px borders in `#E9ECEF` to define containers. 
- **Resting state:** Flat, 1px light gray border.
- **Elevated state (Product Cards):** A very soft, ambient shadow (0px 4px 20px rgba(0,0,0,0.05)) is used only on hover to indicate interactivity.
- **Overlays (Modals):** High-diffusion shadow (0px 12px 40px rgba(0,0,0,0.1)) to separate critical decision-making layers from the background.
Surface stacking always moves from darker (background) to lighter (interactive elements).

## Shapes
The shape language is **Soft** (roundedness 1). This choice balances the rigidity of medical equipment with a modern, approachable software feel. Standard elements like buttons and input fields use a 4px corner radius. Larger containers, such as product selection cards, utilize 8px (rounded-lg) to soften the overall interface and make the e-commerce experience feel more premium and less industrial.

## Components
- **Buttons:** Primary buttons are solid `#005EB8` with white text. Secondary buttons use a 1px border of the primary color with a transparent background. High-end precision is conveyed through 16px horizontal padding and 12px vertical padding.
- **Product Selection Cards:** Use a white background, 1px border, and a subtle 0.5s transition to a light shadow on hover. Images must be on a neutral `#F8F9FA` background for consistency.
- **Hierarchical Navigation:** A vertical "tree" style sidebar for categories. Active categories are indicated with a 3px left-border highlight in Primary Blue.
- **Option Selection Lists:** For selecting drill bits or material types, use "Row-based" radio buttons with explicit technical labels and a subtle background tint (`#F1F3F5`) on hover.
- **Input Fields:** Use a 1px `#DDE2E5` border that transitions to the Primary Blue on focus. Labels must be positioned strictly above the field for medical data entry clarity.
- **Status Chips:** High-contrast background with bold text (e.g., "In Stock" uses light green background with dark green text) to provide instant visual feedback on inventory.