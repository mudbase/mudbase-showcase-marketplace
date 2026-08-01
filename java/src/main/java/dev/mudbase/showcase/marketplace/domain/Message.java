package dev.mudbase.showcase.marketplace.domain;

import dev.mudbase.showcase.marketplace.mudbase.DocumentMapper;
import java.util.Map;

/** Mirrors one row of the `messages` collection - see ../../../web/plan/build-plan.md. */
public class Message {

  private final String id;
  private final String listingId;
  private final String senderId;
  private final String senderName;
  private final String content;
  private final String createdAt;

  private Message(String id, String listingId, String senderId, String senderName, String content, String createdAt) {
    this.id = id;
    this.listingId = listingId;
    this.senderId = senderId;
    this.senderName = senderName;
    this.content = content;
    this.createdAt = createdAt;
  }

  public static Message fromDocument(Map<String, Object> doc) {
    return new Message(
        DocumentMapper.getId(doc),
        DocumentMapper.getString(doc, "listingId"),
        DocumentMapper.getString(doc, "senderId"),
        DocumentMapper.getString(doc, "senderName", "Someone"),
        DocumentMapper.getString(doc, "content", ""),
        DocumentMapper.getString(doc, "createdAt"));
  }

  public String getId() {
    return id;
  }

  public String getListingId() {
    return listingId;
  }

  public String getSenderId() {
    return senderId;
  }

  public String getSenderName() {
    return senderName;
  }

  public String getContent() {
    return content;
  }

  public String getCreatedAt() {
    return createdAt;
  }
}
