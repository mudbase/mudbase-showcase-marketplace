import { ScrollView, Text, View } from "react-native";
import { Link, router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { LoginForm } from "@/components/auth/LoginForm";

export default function LoginScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="flex-grow justify-center px-6 py-10" keyboardShouldPersistTaps="handled">
        <View className="mb-8 gap-1">
          <Text className="text-3xl font-semibold text-foreground">Mudbase Marketplace</Text>
          <Text className="text-muted-foreground">Sign in to post listings, submit proposals, or message.</Text>
        </View>
        {/* router.replace (not back()) since a successful sign-in should land on the listings
            feed, not necessarily wherever this modal happened to be opened from. */}
        <LoginForm onSuccess={() => router.replace("/")} />
        <View className="mt-6 flex-row justify-center gap-1">
          <Text className="text-sm text-muted-foreground">New here?</Text>
          <Link href="/register" replace className="text-sm font-medium text-primary">
            Create an account
          </Link>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
