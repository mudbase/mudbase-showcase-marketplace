package dev.mudbase.showcase.marketplace.config;

import jakarta.annotation.PostConstruct;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Every ID this app needs to talk to a provisioned Mudbase project. See java/.env.example for
 * the full list and where each value comes from. None of these are secrets - the project id and
 * collection ids are public identifiers; the only credential this app ever holds is the
 * signed-in user's own bearer JWT (see {@link dev.mudbase.showcase.marketplace.auth.AuthSession}).
 */
@ConfigurationProperties(prefix = "mudbase")
public class MudbaseProperties {

  private String baseUrl;
  private String projectId;
  private String listingsCollectionId;
  private String proposalsCollectionId;
  private String messagesCollectionId;

  @PostConstruct
  void validate() {
    requireNonBlank(projectId, "mudbase.project-id (MUDBASE_PROJECT_ID)");
    requireNonBlank(listingsCollectionId, "mudbase.listings-collection-id (MUDBASE_LISTINGS_COLLECTION_ID)");
    requireNonBlank(proposalsCollectionId, "mudbase.proposals-collection-id (MUDBASE_PROPOSALS_COLLECTION_ID)");
    requireNonBlank(messagesCollectionId, "mudbase.messages-collection-id (MUDBASE_MESSAGES_COLLECTION_ID)");
  }

  private static void requireNonBlank(String value, String name) {
    if (value == null || value.isBlank()) {
      throw new IllegalStateException("Missing required configuration value: " + name);
    }
  }

  public String getBaseUrl() {
    return baseUrl;
  }

  public void setBaseUrl(String baseUrl) {
    this.baseUrl = baseUrl;
  }

  public String getProjectId() {
    return projectId;
  }

  public void setProjectId(String projectId) {
    this.projectId = projectId;
  }

  public String getListingsCollectionId() {
    return listingsCollectionId;
  }

  public void setListingsCollectionId(String listingsCollectionId) {
    this.listingsCollectionId = listingsCollectionId;
  }

  public String getProposalsCollectionId() {
    return proposalsCollectionId;
  }

  public void setProposalsCollectionId(String proposalsCollectionId) {
    this.proposalsCollectionId = proposalsCollectionId;
  }

  public String getMessagesCollectionId() {
    return messagesCollectionId;
  }

  public void setMessagesCollectionId(String messagesCollectionId) {
    this.messagesCollectionId = messagesCollectionId;
  }
}
