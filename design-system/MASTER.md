# TravelSpendPlus Design System

## Direction

TravelSpendPlus uses a **Coastal Warm Functionalist** interface: calm enough
for repeated bookkeeping, warm enough for personal travel, and structured so
budget numbers remain the primary visual hierarchy.

This file records the existing Flutter design language. It does not authorize
an unrelated visual redesign.

## Color Tokens

| Role | Value | Flutter token |
| --- | --- | --- |
| Primary action | `#E0693F` | `AppColors.coral` |
| Actual spending | `#2A9D8F` | `AppColors.teal` |
| Planned spending | `#8C6D1F` | `AppColors.gold` |
| Page background | `#FBF6EF` | `AppColors.cream` |
| Primary text | `#2B241D` | `AppColors.charcoal` |
| Secondary text | `#8A7F70` | `AppColors.mutedText` |
| Border | `#EFE4D5` | `AppColors.border` |

Use semantic tokens from `app/lib/ui/theme.dart`; do not add page-local colors
for established states. Color never replaces the `Actual` or `Planned` text
label.

## Typography and Numbers

- Use Flutter's Material platform typography; do not add network fonts.
- Preserve the existing type hierarchy: headline for trip names, title for
  sections, body for labels, and compact captions only for secondary data.
- Monetary values must keep currency codes and use stable, readable figures.
- Prefer wrapping over truncating translated labels.

## Spacing and Surfaces

- Base spacing unit: 4dp; normal rhythm: 8, 12, 16, 24, and 32dp.
- Page gutters: 16dp on phones.
- Cards: white surface, 16dp radius, `AppColors.border` outline.
- Interactive controls retain Material touch targets of at least 48dp.

## Responsive Contract

- Design and test from 320dp upward; 375–432dp is the primary phone range.
- No horizontal overflow or horizontally clipped content at any supported
  locale or normal text scale.
- Use `LayoutBuilder` when a component changes structure based on available
  width.
- On narrow widths, budget totals, legends, and segmented controls may move to
  a second line. Preserve reading order and use 8dp vertical separation.
- On wider widths, the same elements may remain inline when they fit.
- Charts keep their visible legend. Controls must not compress the chart or
  force labels outside the viewport.

## Trip Detail Page

- Priority order: trip identity, actual spending, daily rate, budget summary,
  category/location breakdown, expense rows.
- The budget currency control aligns with the total on wide layouts and moves
  below it on narrow layouts.
- Actual, planned, and remaining legends use a wrapping layout rather than
  shrinking text.
- The breakdown dimension control moves below its heading on narrow layouts.

## Accessibility and QA

- Maintain at least 4.5:1 contrast for normal text and 3:1 for large text and
  meaningful graphical elements.
- Preserve text labels for chart and status colors.
- Verify 320, 375, 432, and 600dp widths before release.
- Verify English, German, and Chinese layouts for overflow.
- Store screenshots must contain real rendered app UI, no personal data, and
  no debug overflow markers.
