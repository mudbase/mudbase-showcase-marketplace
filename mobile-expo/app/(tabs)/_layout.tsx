import { Tabs } from "expo-router";
import { Compass, UserRound } from "lucide-react-native";
import type { ColorValue } from "react-native";

const FALLBACK_ICON_COLOR = "#181d25";

/**
 * `Tabs.Screen`'s `tabBarIcon` hands back React Navigation's broader `ColorValue`, while
 * lucide-react-native icons only accept a plain `string`. Every tint color configured below is
 * always a literal hex string, so this narrows safely without a cast.
 */
function toIconColor(color: ColorValue): string {
  return typeof color === "string" ? color : FALLBACK_ICON_COLOR;
}

/**
 * Unlike the sibling mudbase-showcase-kanban port, this app has no global "must sign in first"
 * gate here — an anonymous guest session covers public browsing (see plan/build-plan.md "Auth
 * flow"), so both tabs are always reachable. The "You" tab renders a role-appropriate dashboard
 * (client → my listings, freelancer → my proposals, guest → a sign-in prompt) rather than
 * redirecting away.
 */
export default function TabsLayout(): React.JSX.Element {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#1d8663",
        tabBarInactiveTintColor: "#606876",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: "Browse", tabBarIcon: ({ color, size }) => <Compass color={toIconColor(color)} size={size} /> }}
      />
      <Tabs.Screen
        name="mine"
        options={{ title: "You", tabBarIcon: ({ color, size }) => <UserRound color={toIconColor(color)} size={size} /> }}
      />
    </Tabs>
  );
}
