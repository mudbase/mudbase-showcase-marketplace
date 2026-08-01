import { create } from "zustand";
import { mudbaseClient, MudbaseApiError, type RegisterParams } from "@/api/client";
import type { MudbaseUser } from "@/api/schemas";

interface AuthState {
  user: MudbaseUser | null;
  /** True only while the boot-time restoreTokens()+getSession() (or anonymous fallback)
   * sequence is running. */
  isInitializing: boolean;
  isSubmitting: boolean;
  error: string | null;
  initialize: () => Promise<void>;
  login: (email: string, password: string) => Promise<boolean>;
  register: (params: RegisterParams) => Promise<boolean>;
  logout: () => Promise<void>;
  clearError: () => void;
}

function messageFrom(err: unknown, fallback: string): string {
  return err instanceof MudbaseApiError ? err.message : fallback;
}

/**
 * A plain in-memory zustand store, not persisted via MMKV/AsyncStorage — the only durable state
 * is the token pair in SecureStore (mudbaseClient owns that).
 *
 * Unlike the sibling `mudbase-showcase-kanban` port, this app DOES fall back to an anonymous
 * guest session — this project's `listings` collection grants public read to any authenticated
 * session, anonymous included (see plan/build-plan.md "Auth flow"), mirroring
 * web/src/lib/mudbase-provider.tsx's own bootstrap: restore a real session if one exists,
 * otherwise establish a fresh anonymous one so the public listings feed still works without
 * forcing signup. `logout()` re-establishes a fresh anonymous session immediately afterward for
 * the same reason — this app's mobile UX shouldn't require an app restart just to keep browsing
 * as a guest after signing out.
 */
export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isInitializing: true,
  isSubmitting: false,
  error: null,

  initialize: async (): Promise<void> => {
    set({ isInitializing: true });
    const hasTokens = await mudbaseClient.restoreTokens();
    if (hasTokens) {
      const user = await mudbaseClient.getSession();
      if (user) {
        set({ user, isInitializing: false });
        return;
      }
    }
    // No tokens, or a restored session that failed to validate - fall back to a fresh anonymous
    // session so guest browsing still works (see class doc comment above).
    try {
      const guest = await mudbaseClient.loginAnonymous();
      set({ user: guest, isInitializing: false });
    } catch {
      set({ user: null, isInitializing: false });
    }
  },

  login: async (email, password): Promise<boolean> => {
    set({ isSubmitting: true, error: null });
    try {
      const user = await mudbaseClient.login(email, password);
      set({ user, isSubmitting: false });
      return true;
    } catch (err) {
      set({ error: messageFrom(err, "Login failed. Check your email and password."), isSubmitting: false });
      return false;
    }
  },

  register: async (params): Promise<boolean> => {
    set({ isSubmitting: true, error: null });
    try {
      const user = await mudbaseClient.register(params);
      set({ user, isSubmitting: false });
      return true;
    } catch (err) {
      set({ error: messageFrom(err, "Registration failed."), isSubmitting: false });
      return false;
    }
  },

  logout: async (): Promise<void> => {
    set({ isSubmitting: true });
    await mudbaseClient.logout();
    try {
      const guest = await mudbaseClient.loginAnonymous();
      set({ user: guest, isSubmitting: false });
    } catch {
      set({ user: null, isSubmitting: false });
    }
  },

  clearError: (): void => set({ error: null }),
}));
