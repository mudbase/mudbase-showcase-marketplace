"use client"

import { useState, useCallback } from "react"
import { useRouter } from "next/navigation"
import { useMudbase } from "@/lib/mudbase-provider"
import { MudbaseError, type AppRole, type UserObject } from "@/lib/mudbase"

interface UseAuthReturn {
  user: UserObject | null
  /** A real, role-carrying account - distinct from the always-present anonymous guest session. */
  isAuthenticated: boolean
  /** Convenience narrowing of user.customRole for gating role-specific UI. */
  role: AppRole | null
  loading: boolean
  error: string | null
  register: (
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    role: AppRole,
    agreedToTerms: boolean,
  ) => Promise<boolean>
  login: (email: string, password: string, options?: { redirect?: boolean }) => Promise<boolean>
  logout: () => Promise<void>
  clearError: () => void
}

export function useAuth(): UseAuthReturn {
  const { client, session, loading: sessionLoading, refreshSession } = useMudbase()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const register = useCallback(
    async (
      email: string,
      password: string,
      firstName: string,
      lastName: string,
      role: AppRole,
      agreedToTerms: boolean,
    ): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        await client.register({ email, password, firstName, lastName, role, agreedToTerms })
        await refreshSession()
        router.push(role === "client" ? "/listings/mine" : "/proposals")
        return true
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Registration failed")
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, router, refreshSession],
  )

  const login = useCallback(
    async (email: string, password: string, options?: { redirect?: boolean }): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        const res = await client.login({ email, password })
        await refreshSession()
        if (options?.redirect !== false) {
          router.push(res.user.customRole === "client" ? "/listings/mine" : "/")
        }
        return true
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Login failed")
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, router, refreshSession],
  )

  const logout = useCallback(async () => {
    setLoading(true)
    try {
      await client.logout()
      await refreshSession()
      router.push("/")
    } finally {
      setLoading(false)
    }
  }, [client, router, refreshSession])

  const user = session?.user ?? null
  const role = user?.customRole === "client" || user?.customRole === "freelancer" ? user.customRole : null

  return {
    user,
    // The provider always establishes an anonymous session so guests can browse listings - a
    // "real" signed-in user is one with an actual application role, not that always-present
    // anonymous identity (isAnonymous true, customRole null).
    isAuthenticated: !!user && user.isAnonymous !== true && !!role,
    role,
    loading: loading || sessionLoading,
    error,
    register,
    login,
    logout,
    clearError: () => setError(null),
  }
}
