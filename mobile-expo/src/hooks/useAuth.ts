import { useAuthStore } from "@/stores/authStore";
import { appRoleSchema, type AppRole, type MudbaseUser } from "@/api/schemas";
import type { RegisterParams } from "@/api/client";

interface UseAuthReturn {
  user: MudbaseUser | null;
  /** A real, role-carrying account - distinct from the always-present anonymous guest session
   * established at boot for public browsing. */
  isAuthenticated: boolean;
  /** Convenience narrowing of user.customRole for gating role-specific UI. */
  role: AppRole | null;
  isInitializing: boolean;
  isSubmitting: boolean;
  error: string | null;
  register: (params: RegisterParams) => Promise<boolean>;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
  clearError: () => void;
}

/** Thin selector hook over the auth store - screens read/act through this, never the store
 * directly. Mirrors web/src/hooks/useAuth.ts's semantics exactly. */
export function useAuth(): UseAuthReturn {
  const user = useAuthStore((s) => s.user);
  const isInitializing = useAuthStore((s) => s.isInitializing);
  const isSubmitting = useAuthStore((s) => s.isSubmitting);
  const error = useAuthStore((s) => s.error);
  const login = useAuthStore((s) => s.login);
  const register = useAuthStore((s) => s.register);
  const logout = useAuthStore((s) => s.logout);
  const clearError = useAuthStore((s) => s.clearError);

  const parsedRole = appRoleSchema.safeParse(user?.customRole);
  const role = parsedRole.success ? parsedRole.data : null;

  return {
    user,
    // The store always establishes an anonymous session so guests can browse listings - a "real"
    // signed-in user is one with an actual application role, not that always-present anonymous
    // identity (isAnonymous true, customRole null).
    isAuthenticated: !!user && user.isAnonymous !== true && !!role,
    role,
    isInitializing,
    isSubmitting,
    error,
    register,
    login,
    logout,
    clearError,
  };
}
