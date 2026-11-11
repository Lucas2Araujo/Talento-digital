---
name: "Talento Digital - Adventure Explorers"
description: "A playful, kid-friendly adventure & treasure design system for tablet and mobile gamified learning and rewarding."
---

## Overview

"Talento Digital" is a gamified, kid-friendly school and Sabbath/community group experience where children become brave "Adventure Explorers" collecting shiny Gold Talents ("Talentos de Ouro") through good deeds, Bible study, attendance, and tasks.

The visual style blends **Playful Tactility** (reminiscent of Duolingo and Nintendo's Animal Crossing) with a warm **Treasure Map & Exploration** theme. Chunky 3D-styled pill buttons with solid bottom borders ("squishy" pressable surfaces), warm parchment cream ground, rich forest green accents, bright sky blue badges, and glowing golden treasure coins make every interaction joyful, tactile, and rewarding.

## Colors

The color palette directly honors the user's specification:
- **Warm Cream Ground:** `#FAF3E0` delivers an inviting, warm parchment paper look.
- **Forest Green:** `#2A9D8F` provides adventurous nature contrast for primary actions and affirmative rewards.
- **Sky Blue:** `#219EBC` serves as the explorer compass & badge identifier.
- **Gold Coin Yellow:** `#FFB703` gives radiant energy to treasure balances, coins, and rewards.
- **Wood-Brown Border & Accents:** `#8B5A2B` adds tactile wooden toy chests, frames, and borders.
- Complementary dark tones (`#1E1B18`) and crisp whites ensure high accessibility and tactile pop.

```yaml
colors:
  forest-green: "#2A9D8F"
  sky-blue: "#219EBC"
  gold-coin: "#FFB703"
  wood-brown: "#8B5A2B"
  gold-dark: "#D48B00"
  forest-green-dark: "#1F756B"
  wood-dark: "#5E3B1B"
  sky-blue-dark: "#166B80"
  success: "#2A9D8F"
  warning: "#FFB703"
  error: "#E76F51"
  light:
    primary: "#2A9D8F"
    on-primary: "#262626"
    secondary: "#FFB703"
    on-secondary: "#3A2600"
    tertiary: "#219EBC"
    on-tertiary: "#2B2B2B"
    surface: "#FAF3E0"
    on-surface: "#2D261E"
    surface-variant: "#F3EAD3"
    on-surface-variant: "#6B5E50"
    outline: "#8B5A2B"
  dark:
    primary: "#48CAE4"
    on-primary: "#03045E"
    secondary: "#FFD166"
    on-secondary: "#3A2600"
    tertiary: "#52B788"
    on-tertiary: "#081C15"
    surface: "#221C16"
    on-surface: "#F7EDE2"
    surface-variant: "#322921"
    on-surface-variant: "#C4B5A5"
    outline: "#D4A373"
```

## Typography

Playful, friendly, and legible typography built for young explorers. We pair **Fredoka** (a rounded, warm, chunky headline font full of character) with **Nunito** (a clear, cheerful rounded sans-serif with exceptional readability).

```yaml
typography:
  display-lg:
    fontFamily: "Fredoka"
    fontSize: 40px
    fontWeight: 700
    lineHeight: 48px
    letterSpacing: -0.5px
  display-lg-mobile:
    fontFamily: "Fredoka"
    fontSize: 30px
    fontWeight: 700
    lineHeight: 38px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: "Fredoka"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: "Fredoka"
    fontSize: 24px
    fontWeight: 700
    lineHeight: 32px
  headline-md:
    fontFamily: "Fredoka"
    fontSize: 24px
    fontWeight: 600
    lineHeight: 32px
  title-lg:
    fontFamily: "Fredoka"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 28px
  title-md:
    fontFamily: "Nunito"
    fontSize: 18px
    fontWeight: 700
    lineHeight: 26px
  body-lg:
    fontFamily: "Nunito"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 24px
  body-md:
    fontFamily: "Nunito"
    fontSize: 14px
    fontWeight: 500
    lineHeight: 20px
  label-lg:
    fontFamily: "Fredoka"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 22px
    letterSpacing: 0.2px
  label-md:
    fontFamily: "Fredoka"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 18px
  label-sm:
    fontFamily: "Nunito"
    fontSize: 12px
    fontWeight: 700
    lineHeight: 16px
```

## Layout & Spacing

An 8px modular spacing system designed for tablet and mobile viewports. Touch targets are large and comfortable for children's fingers (minimum 48px height/width).

```yaml
spacing:
  gutter-xs: 4px
  gutter-sm: 8px
  gutter-md: 16px
  gutter-lg: 24px
  gutter-xl: 32px
  section: 40px
  page-margin: 20px
```

## Elevation & Depth

Tactile physical elevation! Instead of soft corporate drop shadows, we employ **Duolingo-style 3D block borders**: a solid border (usually 2px-3px of wood-brown `#8B5A2B` or darkened base color) combined with an offset bottom extrusion (`box-shadow: 0 4px 0 #5E3B1B` or `0 4px 0 #1F756B`). When pressed or active, the button translates down 2px, providing an unmistakable, satisfying tactile click.

Glowing effects are reserved for treasure moments: soft golden halos around gold coins, NFC magic waves, and badge borders.

## Shapes

Shapes feature generous, friendly radii. The user specified rounded corners (24px). Buttons and pills use pill/full radius (9999px) or large 20-24px rounded corners.

```yaml
rounded:
  sm: 8px
  md: 14px
  lg: 18px
  xl: 24px
  full: 9999px
```

## Motion & Micro-interaction

- **Button Press:** 100ms snappy spring translation down 3px with shadow collapse.
- **NFC Wave Animation:** Gentle pulsating concentric waves radiating from the magic card reader.
- **Coin Sparkle:** Subdued 1.5s scale pulse highlighting earned talent counters.

```yaml
motion:
  tactile-press:
    duration: 100ms
    delay: 0ms
    timingFunction: cubic-bezier(0.4, 0, 0.2, 1)
  modal-spring:
    duration: 250ms
    delay: 0ms
    timingFunction: cubic-bezier(0.175, 0.885, 0.32, 1.275)
  coin-pulse:
    duration: 1200ms
    delay: 0ms
    timingFunction: ease-in-out
```

## Voice & Content Strategy

- **Tone:** Enthusiastic, warm, encouraging, and adventurous. Portuguese language ("Aventureiros", "Exploradores", "Talentos de Ouro", "Cartão Mágico").
- **Terminology:**
  - Kids are **Exploradores** (Explorers).
  - Coins/Currency are **Talentos** (🪙).
  - The card is **Cartão Mágico NFC**.
  - The store is **Vitrine da Feirinha**.
  - Teacher view toggle is **Modo Consulta** / **Modo Professor**.
- **Action Verbs:** "Aproxime seu Cartão", "Adicionar Talentos", "Pagar com Cartão Mágico".

## Components

Component implementations live as individual HTML sticker sheet files in
`components/`. Each file contains the canonical, styled HTML components with
`<!-- COMPONENT: name -->` comment markers. Read each file before use.

- **Button** → `@components/button.html`: `button-primary`, `button-icon`, `button-with-icon`
- **Card** → `@components/card.html`: `card-elevated`, `card-action`, `card-interactive`, `card-interactive-2`
- **Chip** → `@components/chip.html`: `chip-action`, `chip-input`, `chip-with-icon`
- **Modal** → `@components/modal.html`: `modal-standard`, `modal-alert`, `modal-drawer`
