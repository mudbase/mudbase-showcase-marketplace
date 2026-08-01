import { Text, View } from "react-native";
import { router } from "expo-router";
import { LogOut } from "lucide-react-native";
import { useAuth } from "@/hooks/useAuth";
import { Badge, type BadgeVariant } from "@/components/ui/Badge";
import { IconButton } from "@/components/ui/IconButton";
import { Button } from "@/components/ui/Button";

const roleBadgeVariant: Record<"client" | "freelancer", BadgeVariant> = {
  client: "default",
  freelancer: "secondary",
};

const roleLabel: Record<"client" | "freelancer", string> = {
  client: "Client",
  freelancer: "Freelancer",
};

/**
 * A small per-screen header (title, current-user identity, sign-in/out) shown at the top of
 * every tab screen's content — the RN equivalent of web/src/components/layout/Header.tsx, since
 * Expo Router's native stack header does not carry per-role state naturally and there is no
 * meaningful mobile equivalent of a persistent sticky web header across a bottom-tab layout.
 */
export function AppHeader({ title }: { title: string }): React.JSX.Element {
  const { user, role, isAuthenticated, logout } = useAuth();

  return (
    <View className="flex-row items-center justify-between px-4 pb-3 pt-2">
      <View className="gap-0.5">
        <Text className="text-2xl font-bold text-foreground">{title}</Text>
        {isAuthenticated && user && (
          <Text className="text-xs text-muted-foreground">
            {user.firstName} {user.lastName}
          </Text>
        )}
      </View>
      <View className="flex-row items-center gap-2">
        {role && <Badge variant={roleBadgeVariant[role]}>{roleLabel[role]}</Badge>}
        {isAuthenticated ? (
          <IconButton accessibilityLabel="Sign out" onPress={() => void logout()}>
            <LogOut size={18} color="#606876" />
          </IconButton>
        ) : (
          <Button variant="outline" size="sm" onPress={() => router.push("/login")}>
            Sign in
          </Button>
        )}
      </View>
    </View>
  );
}
