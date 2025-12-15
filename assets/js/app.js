// Minimal JS bundle for Phoenix 1.8 esbuild profile
// LiveView JS can be added later; for now just ensure bundling works
console.log('ui_web app.js loaded');

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

const Hooks = {}

// Clipboard copy hook
Hooks.ClipboardCopy = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const targetSelector = this.el.dataset.target
      if (!targetSelector) return

      const target = document.querySelector(targetSelector)
      if (!target) return

      const content = target.textContent || target.innerText

      navigator.clipboard.writeText(content).then(() => {
        const original = this.el.textContent
        this.el.textContent = "Copied!"
        setTimeout(() => {
          this.el.textContent = original
        }, 1500)
      }).catch(err => {
        console.error("Failed to copy:", err)
      })
    })
  }
}

// File download hook
Hooks.FileDownload = {
  mounted() {
    this.handleEvent("download", ({content, filename, mime_type}) => {
      try {
        const blob = new Blob([atob(content)], {type: mime_type})
        const url = URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = url
        a.download = filename
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(url)
      } catch (err) {
        console.error("Download failed:", err)
      }
    })
  }
}

Hooks.MessagesSSE = {
    mounted() {
        const url = this.el.dataset.sseUrl
        if (!url) return
        try {
            const es = new EventSource(url)
            this.__es = es

            const push = (evt, data) => {
                try {
                    const payload = typeof data === 'string' ? JSON.parse(data) : data
                    this.pushEvent("sse_message", { event: evt, data: payload })
                } catch (err) {
                    console.warn("SSE parse error", err)
                }
            }

            es.addEventListener("message_created", (e) => push("message_created", e.data))
            es.addEventListener("message_updated", (e) => push("message_updated", e.data))
            es.addEventListener("message_deleted", (e) => push("message_deleted", e.data))
            es.onmessage = (e) => push("message_created", e.data) // default
            es.onerror = () => { /* fallback to polling handled on server; no-op */ }
        } catch (_) {
            // EventSource not available or URL invalid; fallback to polling
        }
    },
    destroyed() {
        if (this.__es) {
            try { this.__es.close() } catch (_) { }
        }
    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })
liveSocket.connect()
window.liveSocket = liveSocket