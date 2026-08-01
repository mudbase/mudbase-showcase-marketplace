import { ScrollView, Text } from "react-native";
import { router, Stack, useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/hooks/useAuth";
import { useDocument, useUpdateDocument } from "@/hooks/useCollection";
import { ListingForm, type ListingFormValues } from "@/components/listings/ListingForm";
import { Button } from "@/components/ui/Button";
import { listingSchema, type Listing } from "@/api/schemas";
import { LISTINGS_COLLECTION_ID } from "@/config/env";

export default function EditListingScreen(): React.JSX.Element {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user, role, isAuthenticated, isInitializing } = useAuth();
  const { data: listing, isLoading, isError } = useDocument(listingSchema, LISTINGS_COLLECTION_ID, id);
  const updateListing = useUpdateDocument<Listing>(listingSchema, LISTINGS_COLLECTION_ID);

  if (isLoading || isInitializing) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background">
        <Stack.Screen options={{ title: "Edit listing" }} />
        <Text className="text-sm text-muted-foreground">Loading…</Text>
      </SafeAreaView>
    );
  }

  if (isError || !listing) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background px-6">
        <Stack.Screen options={{ title: "Edit listing" }} />
        <Text className="text-center text-sm text-muted-foreground">This listing couldn&apos;t be found.</Text>
      </SafeAreaView>
    );
  }

  const isOwner = isAuthenticated && role === "client" && !!user && listing.clientId === user.id;
  if (!isOwner) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center gap-4 bg-background px-6">
        <Stack.Screen options={{ title: "Edit listing" }} />
        <Text className="text-center text-sm text-muted-foreground">
          Only the client who posted this listing can edit it.
        </Text>
        <Button variant="outline" onPress={() => router.replace(`/listings/${id}`)}>
          Back to listing
        </Button>
      </SafeAreaView>
    );
  }

  const handleSubmit = async (values: ListingFormValues): Promise<void> => {
    await updateListing.mutateAsync({
      documentId: id,
      data: {
        title: values.title,
        description: values.description,
        budget: values.budget,
        category: values.category || undefined,
        status: values.status ?? listing.status,
      },
    });
    router.replace(`/listings/${id}`);
  };

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <Stack.Screen options={{ title: "Edit listing" }} />
      <ScrollView contentContainerClassName="gap-4 p-4" keyboardShouldPersistTaps="handled">
        <Text className="text-sm text-muted-foreground">Update the details or change its status.</Text>
        <ListingForm
          mode="edit"
          initialValues={{
            title: listing.title,
            description: listing.description,
            budget: listing.budget,
            category: listing.category ?? "",
            status: listing.status,
          }}
          submitting={updateListing.isPending}
          submitLabel="Save changes"
          onSubmit={handleSubmit}
        />
      </ScrollView>
    </SafeAreaView>
  );
}
