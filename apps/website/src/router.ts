import { createRouter, createWebHistory } from 'vue-router'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: () => import('./pages/HomePage.vue') },
    { path: '/docs', name: 'docs', component: () => import('./pages/DocsPage.vue') },
    { path: '/privacy', name: 'privacy', component: () => import('./pages/PrivacyPage.vue') },
    { path: '/support', name: 'support', component: () => import('./pages/SupportPage.vue') },
  ],
  scrollBehavior(_to, _from, savedPosition) {
    if (savedPosition) return savedPosition
    return { left: 0, top: 0 }
  },
})
