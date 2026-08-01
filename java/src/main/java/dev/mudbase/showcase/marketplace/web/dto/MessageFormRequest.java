package dev.mudbase.showcase.marketplace.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class MessageFormRequest {

  @NotBlank(message = "Message cannot be empty")
  @Size(max = 2000, message = "Keep messages under 2000 characters")
  private String content = "";

  public String getContent() {
    return content;
  }

  public void setContent(String content) {
    this.content = content;
  }
}
