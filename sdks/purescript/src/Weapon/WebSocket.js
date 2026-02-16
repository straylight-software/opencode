// FFI for EventSource (Server-Sent Events)
// Works in both browser and Node.js (with eventsource polyfill)

export const createEventSource = (url) => () => {
  // In Node.js, we need the eventsource package
  // In browser, EventSource is global
  if (typeof EventSource === "undefined") {
    // Node.js - try to use the eventsource package or a simple HTTP approach
    const http = require("http")
    const https = require("https")
    const { URL } = require("url")

    const parsedUrl = new URL(url)
    const client = parsedUrl.protocol === "https:" ? https : http

    const fakeEventSource = {
      _listeners: { message: [], error: [], open: [] },
      _request: null,
      close: function () {
        if (this._request) {
          this._request.destroy()
        }
      },
    }

    const req = client.get(url, (res) => {
      // Fire open event
      for (const fn of fakeEventSource._listeners.open) {
        fn()
      }

      let buffer = ""

      res.on("data", (chunk) => {
        buffer += chunk.toString()

        // Parse SSE format: "data: {...}\n\n"
        const lines = buffer.split("\n\n")
        buffer = lines.pop() || "" // Keep incomplete message in buffer

        for (const block of lines) {
          const dataLine = block.split("\n").find((line) => line.startsWith("data:"))
          if (dataLine) {
            const data = dataLine.slice(5).trim() // Remove "data:" prefix
            for (const fn of fakeEventSource._listeners.message) {
              fn({ data })
            }
          }
        }
      })

      res.on("error", (err) => {
        for (const fn of fakeEventSource._listeners.error) {
          fn(err)
        }
      })

      res.on("end", () => {
        // Connection closed
      })
    })

    req.on("error", (err) => {
      for (const fn of fakeEventSource._listeners.error) {
        fn(err)
      }
    })

    fakeEventSource._request = req
    return fakeEventSource
  } else {
    // Browser - use native EventSource
    return new EventSource(url)
  }
}

export const closeEventSource = (es) => () => {
  es.close()
}

export const addMessageListener = (es) => (handler) => () => {
  if (es._listeners) {
    // Our fake EventSource for Node.js
    es._listeners.message.push((event) => {
      handler(event.data)()
    })
  } else {
    // Native EventSource
    es.addEventListener("message", (event) => {
      handler(event.data)()
    })
  }
}

export const addErrorListener = (es) => (handler) => () => {
  if (es._listeners) {
    es._listeners.error.push(() => {
      handler()
    })
  } else {
    es.addEventListener("error", () => {
      handler()
    })
  }
}

export const addOpenListener = (es) => (handler) => () => {
  if (es._listeners) {
    es._listeners.open.push(() => {
      handler()
    })
  } else {
    es.addEventListener("open", () => {
      handler()
    })
  }
}
