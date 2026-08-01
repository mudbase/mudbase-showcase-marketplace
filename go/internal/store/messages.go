package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/models"
)

// messagesPerThreadLimit bounds how many messages a single listing's thread renders - matches the
// reference web app's MessageThread.tsx (`limit: 100`).
const messagesPerThreadLimit = 100

// MessageService implements every operation the app needs against the `messages` collection.
type MessageService struct {
	client       *mbase.Client
	collectionID string
}

// NewMessageService builds a MessageService bound to the given messages collection ID.
func NewMessageService(client *mbase.Client, messagesCollectionID string) *MessageService {
	return &MessageService{client: client, collectionID: messagesCollectionID}
}

// ForListing returns every message on listingID's thread, oldest first - normal chat order. The
// caller (internal/server/handlers_messages.go) must have already verified the current session
// user may see this thread (the client, or the listing's accepted freelancer) before calling this
// - this method itself has no notion of "who is allowed to read this."
func (s *MessageService) ForListing(ctx context.Context, token, listingID string) ([]models.Message, error) {
	result, err := mbase.List[models.Message](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"listingId": listingID},
		Sort:   "createdAt",
		Limit:  messagesPerThreadLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing messages for listing %s: %w", listingID, err)
	}
	return result.Data, nil
}

// Create posts a new message on listingID's thread, authored by senderID/senderName. Same
// caller-must-verify-visibility precondition as ForListing.
func (s *MessageService) Create(ctx context.Context, token, listingID, senderID, senderName, content string) (models.Message, error) {
	created, err := mbase.Create[models.Message](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"listingId":  listingID,
		"senderId":   senderID,
		"senderName": senderName,
		"content":    content,
	})
	if err != nil {
		return models.Message{}, fmt.Errorf("store: creating message on listing %s: %w", listingID, err)
	}
	return created, nil
}
