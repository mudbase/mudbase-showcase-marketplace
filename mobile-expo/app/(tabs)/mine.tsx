import { Text, View } from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { AppHeader } from "@/components/layout/AppHeader";
import { Button } from "@/components/ui/Button";
import { MyListingsView } from "@/components/listings/MyListingsView";
import { MyProposalsView } from "@/components/proposals/MyProposalsView";
import { useAuth } from "@/hooks/useAuth";

/**
 * A single tab whose content depends on role - the RN equivalent of the web reference's two
 * separate routes (`/listings/mine` for clients, `/proposals` for freelancers), unified here to
 * keep this app's bottom-tab navigation to two tabs total (see plan/build-plan.md). A guest
 * (anonymous session, or simply not signed in) sees a sign-in/create-account prompt instead of a
 * redirect, mirroring how the web reference's own per-page guards render an inline CTA rather
 * than bouncing the user away.
 */
export default function MineScreen(): React.JSX.Element {
  const { isAuthenticated, role, isInitializing } = useAuth();

  const title = role === "client" ? "My Listings" : role === "freelancer" ? "My Proposals" : "You";

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <AppHeader title={title} />
      {isInitializing ? (
        <View className="flex-1 items-center justify-center px-6">
          <Text className="text-sm text-muted-foreground">Loading…</Text>
        </View>
      ) : !isAuthenticated ? (
        <View className="flex-1 items-center justify-center gap-4 px-6">
          <Text className="text-center text-sm text-muted-foreground">
            Sign in with a client account to manage your listings, or a freelancer account to track
            your proposals.
          </Text>
          <View className="w-full gap-2">
            <Button onPress={() => router.push("/login")}>Sign in</Button>
            <Button variant="outline" onPress={() => router.push("/register")}>
              Create an account
            </Button>
          </View>
        </View>
      ) : role === "client" ? (
        <MyListingsView />
      ) : (
        <MyProposalsView />
      )}
    </SafeAreaView>
  );
}
