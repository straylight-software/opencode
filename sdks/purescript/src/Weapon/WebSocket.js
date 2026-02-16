// FFI for EventSource (Server-Sent Events)
// Works in both browser and Node.js

// Use dynamic import for Node.js built-in modules (ESM compatible)
let httpModule = null
let httpsModule = null

const getHttp = async () => {
  if (!httpModule) {
    httpModule = await import("node:http")
  }
  return httpModule.default || httpModule
}

const getHttps = async () => {
  if (!httpsModule) {
    httpsModule = await import("node:https")
  }
  return httpsModule.default || httpsModule
}

export const createEventSource = (url) => () => {
  // In browser, EventSource is global
  if (typeof EventSource !== "undefined") {
    return new EventSource(url)
  }

  // Node.js - use built-in http/https modules
  const parsedUrl = new URL(url)

  const fakeEventSource = {
    _listeners: { message: [], error: [], open: [] },
    _request: null,
    readyState: 0, // CONNECTING
    close: function () {
      this.readyState = 2 // CLOSED
      if (this._request) {
        this._request.destroy()
      }
    },
  }

  // Start connection asynchronously
  ;(async () => {
    try {
      const client = parsedUrl.protocol === "https:" ? await getHttps() : await getHttp()

      const req = client.get(url, (res) => {
        fakeEventSource.readyState = 1 // OPEN

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
          fakeEventSource.readyState = 2 // CLOSED
        })
      })

      req.on("error", (err) => {
        for (const fn of fakeEventSource._listeners.error) {
          fn(err)
        }
      })

      fakeEventSource._request = req
    } catch (err) {
      for (const fn of fakeEventSource._listeners.error) {
        fn(err)
      }
    }
  })()

  return fakeEventSource
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
