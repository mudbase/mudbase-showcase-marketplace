package models

// Message mirrors the `messages` Mudbase collection schema - one row per chat message on a
// listing's thread.
type Message struct {
	ID         string `json:"_id"`
	CreatedAt  string `json:"createdAt"`
	UpdatedAt  string `json:"updatedAt"`
	ListingID  string `json:"listingId"`
	SenderID   string `json:"senderId"`
	SenderName string `json:"senderName"`
	Content    string `json:"content"`
}
