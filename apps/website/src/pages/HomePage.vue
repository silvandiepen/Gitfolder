<template>
  <main class="home-page">
    <section class="home-page__hero">
      <p class="home-page__eyebrow">Mac App Store utility · local-first GitHub snapshots</p>
      <h1>Automatic version history for your folders.</h1>
      <p>
        GitFolder is a small macOS menu bar app that watches selected folders and creates quiet GitHub snapshot commits when files change.
      </p>
      <div class="home-page__actions">
        <a href="#app-store" class="button">Coming to the Mac App Store</a>
        <RouterLink to="/docs" class="button button--secondary">Read the docs</RouterLink>
      </div>
    </section>
    <section id="app-store" class="home-page__card">
      <h2>Simple app, simple setup.</h2>
      <ul>
        <li>No GitFolder account or billing backend.</li>
        <li>Uses your existing GitHub SSH setup.</li>
        <li>Your files go only to repositories you choose.</li>
      </ul>
    </section>
  </main>
</template>
