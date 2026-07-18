import { ref, watchEffect, type Ref } from 'vue'
import { markdownToHtml } from 'nizel/browser'

/**
 * Render a markdown source string to HTML with nizel, reactively.
 * Returns a ref of the rendered HTML for use with v-html.
 */
export function useMarkdown(source: () => string): Ref<string> {
  const html = ref('')

  watchEffect(async () => {
    const md = source()
    if (!md) {
      html.value = ''
      return
    }
    html.value = await markdownToHtml(md)
  })

  return html
}
