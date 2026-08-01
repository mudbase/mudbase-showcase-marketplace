"use client"

import React, { createContext, useContext, useEffect, useState, useCallback } from "react"
import { MudbaseClient, initMudbase, type MudbaseConfig, type SessionResponse } from "./mudbase"

interface MudbaseContextValue {
  client: MudbaseClient
  session: SessionResponse | null
  loading: boolean
  refreshSession: () => Promise<void>
}

const MudbaseContext = createContext<MudbaseContextValue | null>(null)

export function MudbaseProvider({
  children,
  config,
}: {
  children: React.ReactNode
  config: MudbaseConfig
}): React.JSX.Element {
  const [client] = useState<MudbaseClient>(() => initMudbase(config))
  const [session, setSession] = useState<SessionResponse | null>(null)
  const [loading, setLoading] = useState<boolean>(true)

  const refreshSession = useCallback(async (): Promise<void> => {
    try {
      const s = await client.getSession()
      setSession(s)
    } catch {
      setSession(null)
      client.clearToken()
    }
  }, [client])

  useEffect(() => {
    const establish = async (): Promise<void> => {
      if (client.getToken()) {
        await refreshSession()
        setLoading(false)
        return
      }
      // Guest browsing: an anonymous session lets the listings feed's "authenticated"-role read
      // permission resolve without forcing signup (same pattern verified live in the
      // ecommerce/social showcases). Posting listings, submitting proposals, and messaging still
      // require a real, role-carrying "client"/"freelancer" account - see useAuth and each page's
      // own guard.
      try {
        await client.loginAnonymous()
        await refreshSession()
      } catch {
        setSession(null)
      } finally {
        setLoading(false)
      }
    }
    void establish()
  }, [client, refreshSession])

  return (
    <MudbaseContext.Provider value={{ client, session, loading, refreshSession }}>
      {children}
    </MudbaseContext.Provider>
  )
}

export function useMudbase(): MudbaseContextValue {
  const ctx = useContext(MudbaseContext)
  if (!ctx) throw new Error("useMudbase must be used inside <MudbaseProvider>")
  return ctx
}
