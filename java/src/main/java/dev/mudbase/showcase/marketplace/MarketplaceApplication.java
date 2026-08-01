package dev.mudbase.showcase.marketplace;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Mudbase Showcase — Marketplace: a freelance marketplace served entirely by Mudbase
 * (cloud.mudbase.dev) — auth, database, role-based access control, no custom backend of any
 * kind. This Spring Boot + Thymeleaf app is the Java reimplementation of the reference Next.js
 * app at ../web - same Mudbase project, same three collections (listings/proposals/messages),
 * same RBAC matrix and business rules; see ../web/plan/build-plan.md for the reference data
 * model and what deliberately differs here (server-rendered forms instead of client-side
 * polling/live search, and why).
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class MarketplaceApplication {

  public static void main(String[] args) {
    SpringApplication.run(MarketplaceApplication.class, args);
  }
}
