import { ScrollView, Text, View } from "react-native";
import { Link, router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { RegisterForm } from "@/components/auth/RegisterForm";

export default function RegisterScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="flex-grow px-6 py-10" keyboardShouldPersistTaps="handled">
        <View className="mb-8 gap-1">
          <Text className="text-3xl font-semibold text-foreground">Create your account</Text>
          <Text className="text-muted-foreground">Post listings as a client, or find work as a freelancer.</Text>
        </View>
        {/* Every new account lands on the "You" tab, which already renders the right dashboard
            (my listings vs. my proposals) for whichever role was just chosen. */}
        <RegisterForm onSuccess={() => router.replace("/mine")} />
        <View className="mt-6 flex-row justify-center gap-1">
          <Text className="text-sm text-muted-foreground">Already have an account?</Text>
          <Link href="/login" replace className="text-sm font-medium text-primary">
            Sign in
          </Link>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
