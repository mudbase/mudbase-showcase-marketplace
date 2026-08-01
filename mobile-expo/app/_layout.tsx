import "../global.css";
import { useEffect } from "react";
import { ActivityIndicator, View } from "react-native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AppProviders } from "@/providers/AppProviders";
import { useAuthStore } from "@/stores/authStore";

function BootSplash(): React.JSX.Element {
  return (
    <View className="flex-1 items-center justify-center bg-background">
      <ActivityIndicator size="large" color="#1d8663" />
    </View>
  );
}

function RootNavigator(): React.JSX.Element {
  const isInitializing = useAuthStore((s) => s.isInitializing);

  useEffect(() => {
    void useAuthStore.getState().initialize();
  }, []);

  // Unlike the sibling mudbase-showcase-kanban port, this app has an anonymous guest session
  // (see plan/build-plan.md "Auth flow"), so the tabs are always reachable once boot finishes —
  // there is no global "redirect to /login if unauthenticated" gate here. Individual screens
  // (post a listing, my listings/proposals, edit) gate themselves per-role instead, exactly
  // mirroring each web reference page's own per-page auth check.
  if (isInitializing) return <BootSplash />;

  return (
    <>
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="login" options={{ headerShown: true, title: "Sign in", presentation: "modal" }} />
        <Stack.Screen name="register" options={{ headerShown: true, title: "Create account", presentation: "modal" }} />
        <Stack.Screen name="listings" />
      </Stack>
    </>
  );
}

export default function RootLayout(): React.JSX.Element {
  return (
    <AppProviders>
      <RootNavigator />
    </AppProviders>
  );
}
