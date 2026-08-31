import { useRef, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";
import { useDocuments, useCreateDocument } from "@/hooks/useCollection";
import { messageSchema, type Message } from "@/api/schemas";
import { MESSAGES_COLLECTION_ID } from "@/config/env";
import { cn } from "@/lib/cn";
import { formatDateTime, initials, isObjectId } from "@/lib/format";

/** No Socket.IO / realtime channel in this app (see plan/build-plan.md) - the thread refreshes
 * via TanStack Query polling, identical in spirit to web/src/components/messages/MessageThread.tsx's
 * `refetchInterval`. */
const POLL_INTERVAL_MS = 4000;

interface MessageThreadProps {
  listingId: string;
  currentUserId: string;
  currentUserName: string;
}

export function MessageThread({ listingId, currentUserId, currentUserName }: MessageThreadProps): React.JSX.Element {
  const [draft, setDraft] = useState("");
  const listRef = useRef<FlatList<Message> | null>(null);
  const { data, isLoading, isError } = useDocuments(
    messageSchema,
    MESSAGES_COLLECTION_ID,
    { filter: { listingId }, sort: "createdAt", limit: 100 },
    { enabled: isObjectId(listingId), refetchInterval: POLL_INTERVAL_MS },
  );
  const createMessage = useCreateDocument<Message>(messageSchema, MESSAGES_COLLECTION_ID);
  const messages = data?.data ?? [];

  const send = async (): Promise<void> => {
    const content = draft.trim();
    if (!content) return;
    setDraft("");
    await createMessage.mutateAsync({ listingId, senderId: currentUserId, senderName: currentUserName, content });
    listRef.current?.scrollToEnd({ animated: true });
  };

  return (
    <View className="gap-3">
      <View className="max-h-96 rounded-lg border border-border bg-secondary/30">
        {isLoading && <Text className="p-4 text-sm text-muted-foreground">Loading messages…</Text>}
        {isError && <Text className="p-4 text-sm text-destructive">Couldn&apos;t load messages.</Text>}
        {!isLoading && !isError && messages.length === 0 && (
          <Text className="p-4 text-sm text-muted-foreground">No messages yet - say hello.</Text>
        )}
        {!isLoading && !isError && messages.length > 0 && (
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(item) => item._id}
            contentContainerClassName="gap-3 p-4"
            onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
            renderItem={({ item: message }) => {
              const isOwn = message.senderId === currentUserId;
              return (
                <View className={cn("flex-row gap-2", isOwn && "flex-row-reverse")}>
                  <View className="h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10">
                    <Text className="text-xs font-semibold text-primary">{initials(message.senderName)}</Text>
                  </View>
                  <View
                    className={cn(
                      "max-w-[75%] rounded-lg px-3 py-2",
                      isOwn ? "bg-primary" : "bg-card",
                    )}
                  >
                    <Text className={cn("text-sm", isOwn ? "text-primary-foreground" : "text-foreground")}>
                      {message.content}
                    </Text>
                    <Text
                      className={cn(
                        "mt-1 text-[11px] opacity-70",
                        isOwn ? "text-primary-foreground" : "text-muted-foreground",
                      )}
                    >
                      {message.senderName} · {formatDateTime(message.createdAt)}
                    </Text>
                  </View>
                </View>
              );
            }}
          />
        )}
      </View>
      <View className="flex-row items-end gap-2">
        <TextField
          containerClassName="flex-1"
          placeholder="Write a message…"
          value={draft}
          onChangeText={setDraft}
          multiline
          numberOfLines={2}
        />
        <Button onPress={() => void send()} disabled={createMessage.isPending || draft.trim().length === 0}>
          Send
        </Button>
      </View>
    </View>
  );
}
