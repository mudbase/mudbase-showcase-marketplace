"use client"

import { useRef, useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { useDocuments, useCreateDocument } from "@/hooks/useCollection"
import { MESSAGES_COLLECTION_ID } from "@/lib/config"
import { cn, formatDateTime, initials, isObjectId } from "@/lib/utils"
import type { Message } from "@/types/message"

const POLL_INTERVAL_MS = 4000

interface MessageThreadProps {
  listingId: string
  currentUserId: string
  currentUserName: string
}

export function MessageThread({ listingId, currentUserId, currentUserName }: MessageThreadProps): React.JSX.Element {
  const [draft, setDraft] = useState("")
  const scrollRef = useRef<HTMLDivElement | null>(null)
  const { data, isLoading, isError } = useDocuments<Message>(
    MESSAGES_COLLECTION_ID,
    { filter: { listingId }, sort: "createdAt", limit: 100 },
    { enabled: isObjectId(listingId), refetchInterval: POLL_INTERVAL_MS },
  )
  const createMessage = useCreateDocument<Message>(MESSAGES_COLLECTION_ID)
  const messages = data?.data ?? []

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight })
  }, [messages.length])

  const send = async (): Promise<void> => {
    const content = draft.trim()
    if (!content) return
    await createMessage.mutateAsync({ listingId, senderId: currentUserId, senderName: currentUserName, content })
    setDraft("")
  }

  return (
    <div className="space-y-3">
      <div ref={scrollRef} className="max-h-96 space-y-3 overflow-y-auto rounded-lg border border-border bg-secondary/30 p-4">
        {isLoading && <p className="text-sm text-muted-foreground">Loading messages…</p>}
        {isError && <p className="text-sm text-destructive">Couldn&apos;t load messages.</p>}
        {!isLoading && !isError && messages.length === 0 && (
          <p className="text-sm text-muted-foreground">No messages yet — say hello.</p>
        )}
        {messages.map((message) => {
          const isOwn = message.senderId === currentUserId
          return (
            <div key={message._id} className={cn("flex gap-2", isOwn && "flex-row-reverse")}>
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary">
                {initials(message.senderName)}
              </div>
              <div className={cn("max-w-[75%] rounded-lg px-3 py-2 text-sm", isOwn ? "bg-primary text-primary-foreground" : "bg-card")}>
                <p className="whitespace-pre-wrap">{message.content}</p>
                <p className={cn("mt-1 text-[11px] opacity-70", isOwn ? "text-primary-foreground" : "text-muted-foreground")}>
                  {message.senderName} · {formatDateTime(message.createdAt)}
                </p>
              </div>
            </div>
          )
        })}
      </div>
      <div className="flex gap-2">
        <Textarea
          rows={2}
          placeholder="Write a message…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault()
              void send()
            }
          }}
        />
        <Button onClick={() => void send()} disabled={createMessage.isPending || draft.trim().length === 0}>
          Send
        </Button>
      </div>
    </div>
  )
}
