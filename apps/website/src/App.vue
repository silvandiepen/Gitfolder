<template>
  <header class="site-header">
    <RouterLink class="site-header__brand" to="/">GitFolder</RouterLink>
    <nav class="site-header__nav" aria-label="Primary navigation">
      <RouterLink to="/docs">Docs</RouterLink>
      <RouterLink to="/privacy">Privacy</RouterLink>
      <RouterLink to="/support">Support</RouterLink>
    </nav>
  </header>
  <RouterView />
</template>
