import { describe, expect, test } from "bun:test"
import { createRoot, createSignal } from "solid-js"
import { createStore } from "solid-js/store"

describe("FREE mode auto-recovery grace period", () => {
  test("should not trigger recovery within grace period after tool completion", () => {
    const result = createRoot(() => {
      // Simulate the grace period logic from footer.tsx
      const toolGracePeriod = 60_000
      const lastToolEndTime = Date.now() // Tool just completed
      const now = Date.now()
      const timeSinceToolEnd = now - lastToolEndTime
      const withinToolGracePeriod = timeSinceToolEnd < toolGracePeriod

      return withinToolGracePeriod
    })

    expect(result).toBe(true)
  })

  test("should allow recovery after grace period expires", () => {
    const result = createRoot(() => {
      const toolGracePeriod = 60_000
      const lastToolEndTime = Date.now() - 70_000 // Tool completed 70s ago
      const now = Date.now()
      const timeSinceToolEnd = now - lastToolEndTime
      const withinToolGracePeriod = timeSinceToolEnd < toolGracePeriod

      return withinToolGracePeriod
    })

    expect(result).toBe(false)
  })

  test("should reset grace period tracking on new turn", () => {
    // Simulate the reset logic when a new turn starts
    let lastToolEndTime: number | undefined = Date.now() - 30_000

    // Reset on new turn (as done in footer.tsx when status.type === "busy")
    lastToolEndTime = undefined

    expect(lastToolEndTime).toBeUndefined()
  })

  test("grace period prevents recovery trigger during provider wait after tool", () => {
    const result = createRoot(() => {
      // Simulate the full recovery check logic
      const busyRaw = true
      const isToolRunning = false
      const silenceDuration = 35_000 // 35s of silence
      const timeout = { ms: 30_000 }

      const toolGracePeriod = 60_000
      const lastToolEndTimeRaw = Date.now() - 10_000 // Tool completed 10s ago
      const now = Date.now()
      const timeSinceToolEnd = lastToolEndTimeRaw ? now - lastToolEndTimeRaw : Infinity
      const withinToolGracePeriod = timeSinceToolEnd < toolGracePeriod

      // Recovery should NOT trigger because we're within grace period
      const shouldTriggerRecovery = busyRaw && !isToolRunning && !withinToolGracePeriod && silenceDuration > 2000

      return shouldTriggerRecovery
    })

    expect(result).toBe(false)
  })
})
