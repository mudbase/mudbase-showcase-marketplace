import { ScrollView, Text, View } from "react-native";
import { router, Stack } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/hooks/useAuth";
import { useCreateDocument } from "@/hooks/useCollection";
import { ListingForm, type ListingFormValues } from "@/components/listings/ListingForm";
import { Button } from "@/components/ui/Button";
import { listingSchema, type Listing } from "@/api/schemas";
import { LISTINGS_COLLECTION_ID } from "@/config/env";

export default function NewListingScreen(): React.JSX.Element {
  const { user, role, isAuthenticated, isInitializing } = useAuth();
  const createListing = useCreateDocument<Listing>(listingSchema, LISTINGS_COLLECTION_ID);

  if (isInitializing) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background">
        <Stack.Screen options={{ title: "Post a listing" }} />
        <Text className="text-sm text-muted-foreground">Loading…</Text>
      </SafeAreaView>
    );
  }

  if (!isAuthenticated || role !== "client" || !user) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center gap-4 bg-background px-6">
        <Stack.Screen options={{ title: "Post a listing" }} />
        <Text className="text-center text-sm text-muted-foreground">
          Sign in with a client account to post a listing.
        </Text>
        <Button onPress={() => router.push("/login")}>Sign in</Button>
      </SafeAreaView>
    );
  }

  const handleSubmit = async (values: ListingFormValues): Promise<void> => {
    const created = await createListing.mutateAsync({
      title: values.title,
      description: values.description,
      budget: values.budget,
      category: values.category || undefined,
      status: "open",
      clientId: user.id,
      clientName: `${user.firstName} ${user.lastName}`,
    });
    router.replace(`/listings/${created._id}`);
  };

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <Stack.Screen options={{ title: "Post a listing" }} />
      <ScrollView contentContainerClassName="gap-4 p-4" keyboardShouldPersistTaps="handled">
        <View className="gap-1">
          <Text className="text-sm text-muted-foreground">
            Freelancers will be able to browse and submit proposals immediately.
          </Text>
        </View>
        <ListingForm mode="create" submitting={createListing.isPending} submitLabel="Post listing" onSubmit={handleSubmit} />
      </ScrollView>
    </SafeAreaView>
  );
}
