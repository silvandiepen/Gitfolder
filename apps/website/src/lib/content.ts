// Shared content-shape types used by pages + content JSON.

/** A single feature card (icon glyph name + title + description). */
export interface Feature {
  icon: string
  title: string
  desc: string
}

/** A numbered how-it-works step. */
export interface Step {
  n: string
  title: string
  desc: string
}

/** A home-page product card. */
export interface AppCardContent {
  app: 'gitfolder' | 'gitkanban'
  name: string
  tagline: string
  points: string[]
  to: string
  cta: string
  badge?: string
}
