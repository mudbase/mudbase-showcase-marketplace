import { ScrollView, Text, View } from "react-native";
import { router, Stack, useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/hooks/useAuth";
import { useDocument, useDocuments, useCreateDocument } from "@/hooks/useCollection";
import { LISTINGS_COLLECTION_ID, PROPOSALS_COLLECTION_ID } from "@/config/env";
import { Card } from "@/components/ui/Card";
import { Badge, type BadgeVariant } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Separator } from "@/components/ui/Separator";
import { ProposalForm, type ProposalFormValues } from "@/components/proposals/ProposalForm";
import { ProposalList } from "@/components/proposals/ProposalList";
import { ProposalStatusBadge } from "@/components/proposals/ProposalStatusBadge";
import { MessageThread } from "@/components/messages/MessageThread";
import { formatCurrency, formatRelativeTime, isObjectId } from "@/lib/format";
import { listingSchema, listingStatusLabel, proposalSchema, type ListingStatus, type Proposal } from "@/api/schemas";

const STATUS_VARIANT: Record<ListingStatus, BadgeVariant> = {
  open: "success",
  in_progress: "warning",
  completed: "secondary",
};

export default function ListingDetailScreen(): React.JSX.Element {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { user, role, isAuthenticated, isInitializing } = useAuth();

  const { data: listing, isLoading, isError } = useDocument(listingSchema, LISTINGS_COLLECTION_ID, id);

  const isOwningClient = isAuthenticated && role === "client" && !!listing && !!user && listing.clientId === user.id;
  const isFreelancer = isAuthenticated && role === "freelancer" && !!user;

  // A freelancer's own proposal on this listing, if any - determines whether to show the
  // submission form or their existing status.
  const { data: ownProposalData, isLoading: ownProposalLoading } = useDocuments(
    proposalSchema,
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: id, freelancerId: user?.id }, limit: 1 },
    { enabled: isFreelancer && isObjectId(id) && isObjectId(user?.id) },
  );
  const ownProposal = ownProposalData?.data[0];

  // Whichever proposal (if any) has been accepted on this listing - decides who besides the
  // client can see and use the message thread. See plan/build-plan.md "Messaging visibility".
  const { data: acceptedProposalData } = useDocuments(
    proposalSchema,
    PROPOSALS_COLLECTION_ID,
    { filter: { listingId: id, status: "accepted" }, limit: 1 },
    { enabled: isAuthenticated && isObjectId(id) },
  );
  const acceptedFreelancerId = acceptedProposalData?.data[0]?.freelancerId;

  const createProposal = useCreateDocument<Proposal>(proposalSchema, PROPOSALS_COLLECTION_ID);

  const canMessage =
    isAuthenticated &&
    !!user &&
    !!listing &&
    (listing.clientId === user.id || (isFreelancer && acceptedFreelancerId === user.id));

  if (isLoading || isInitializing) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background">
        <Stack.Screen options={{ title: "Listing" }} />
        <Text className="text-sm text-muted-foreground">Loading listing…</Text>
      </SafeAreaView>
    );
  }

  if (isError || !listing) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center gap-4 bg-background px-6">
        <Stack.Screen options={{ title: "Listing" }} />
        <Text className="text-center text-sm text-muted-foreground">This listing couldn&apos;t be found.</Text>
        <Button variant="outline" onPress={() => router.replace("/")}>
          Back to listings
        </Button>
      </SafeAreaView>
    );
  }

  const handleSubmitProposal = async (values: ProposalFormValues): Promise<void> => {
    if (!user) return;
    await createProposal.mutateAsync({
      listingId: id,
      freelancerId: user.id,
      freelancerName: `${user.firstName} ${user.lastName}`,
      coverLetter: values.coverLetter,
      proposedRate: values.proposedRate,
      status: "pending",
    });
  };

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <Stack.Screen options={{ title: listing.title }} />
      <ScrollView contentContainerClassName="gap-4 p-4">
        <Card className="gap-3">
          <View className="flex-row items-start justify-between gap-3">
            <View className="flex-1 gap-1">
              <Text className="text-xl font-semibold text-foreground">{listing.title}</Text>
              <Text className="text-sm text-muted-foreground">
                Posted by {listing.clientName} · {formatRelativeTime(listing.createdAt)}
              </Text>
            </View>
            <Badge variant={STATUS_VARIANT[listing.status]}>{listingStatusLabel(listing.status)}</Badge>
          </View>
          <Text className="text-sm text-foreground">{listing.description}</Text>
          <View className="flex-row flex-wrap items-center gap-3">
            <Text className="text-sm font-semibold text-primary">{formatCurrency(listing.budget)}</Text>
            {listing.category && <Badge variant="secondary">{listing.category}</Badge>}
          </View>
          {isOwningClient && (
            <Button variant="outline" size="sm" onPress={() => router.push(`/listings/${listing._id}/edit`)}>
              Edit listing
            </Button>
          )}
        </Card>

        {isFreelancer && (
          <Card className="gap-3">
            <Text className="text-lg font-semibold text-foreground">Your proposal</Text>
            {ownProposalLoading ? (
              <Text className="text-sm text-muted-foreground">Checking your proposal status…</Text>
            ) : ownProposal ? (
              <View className="gap-2">
                <View className="flex-row items-center justify-between">
                  <Text className="text-sm text-muted-foreground">
                    Your proposed rate: {formatCurrency(ownProposal.proposedRate)}
                  </Text>
                  <ProposalStatusBadge status={ownProposal.status} />
                </View>
                <Text className="text-sm text-foreground">{ownProposal.coverLetter}</Text>
              </View>
            ) : (
              <ProposalForm submitting={createProposal.isPending} onSubmit={handleSubmitProposal} />
            )}
          </Card>
        )}

        {isOwningClient && (
          <Card className="gap-3">
            <Text className="text-lg font-semibold text-foreground">Proposals received</Text>
            <ProposalList listingId={id} />
          </Card>
        )}

        {canMessage && user && (
          <>
            <Separator />
            <Card className="gap-3">
              <View className="gap-0.5">
                <Text className="text-lg font-semibold text-foreground">Messages</Text>
                <Text className="text-sm text-muted-foreground">Visible to the client and the accepted freelancer.</Text>
              </View>
              <MessageThread listingId={id} currentUserId={user.id} currentUserName={`${user.firstName} ${user.lastName}`} />
            </Card>
          </>
        )}

        {!isAuthenticated && (
          <View className="items-center gap-2 py-4">
            <Text className="text-center text-sm text-muted-foreground">
              Sign in to submit a proposal or message about this listing.
            </Text>
            <Button variant="outline" size="sm" onPress={() => router.push("/login")}>
              Sign in
            </Button>
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
