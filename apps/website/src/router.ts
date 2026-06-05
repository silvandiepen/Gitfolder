import { createRouter, createWebHistory } from 'vue-router'
import HomePage from './pages/HomePage.vue'
import DocsPage from './pages/DocsPage.vue'
import PrivacyPage from './pages/PrivacyPage.vue'
import SupportPage from './pages/SupportPage.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: HomePage },
    { path: '/docs', component: DocsPage },
    { path: '/privacy', component: PrivacyPage },
    { path: '/support', component: SupportPage },
  ],
  scrollBehavior(_to, _from, savedPosition) {
    if (savedPosition) return savedPosition
    return { left: 0, top: 0 }
  },
})
