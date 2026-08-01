// Package server wires the app's HTTP surface: routing, session handling, and every
// server-rendered page handler, on top of internal/store's domain services.
package server

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/config"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/session"
	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/store"
)

// App bundles every dependency the HTTP handlers need.
type App struct {
	cfg       *config.Config
	sessions  *session.Store
	mudbase   *mbase.Client
	listings  *store.ListingService
	proposals *store.ProposalService
	messages  *store.MessageService
	templates *Templates
}

// New builds the App and its full dependency graph from cfg.
func New(cfg *config.Config) (*App, error) {
	templates, err := loadTemplates()
	if err != nil {
		return nil, fmt.Errorf("server: loading templates: %w", err)
	}

	client := mbase.New(cfg)
	listings := store.NewListingService(client, cfg.ListingsCollectionID)
	proposals := store.NewProposalService(client, cfg.ProposalsCollectionID)
	messages := store.NewMessageService(client, cfg.MessagesCollectionID)

	return &App{
		cfg:       cfg,
		sessions:  session.New(cfg.SessionSecret, cfg.CookieSecure),
		mudbase:   client,
		listings:  listings,
		proposals: proposals,
		messages:  messages,
		templates: templates,
	}, nil
}

// Routes builds the full chi router for this app. Static assets are mounted outside the session
// middleware group - a stylesheet request has no business establishing (or waiting on) a Mudbase
// anonymous session.
func (a *App) Routes() http.Handler {
	root := chi.NewRouter()
	root.Use(middleware.Logger)
	root.Use(middleware.Recoverer)

	staticHandler := http.FileServer(http.FS(staticFS))
	root.Get("/static/*", staticHandler.ServeHTTP)

	r := chi.NewRouter()
	r.Use(a.sessionMiddleware)

	r.Get("/", a.handleHome)

	r.Get("/login", a.handleLoginShow)
	r.Post("/login", a.handleLoginSubmit)
	r.Get("/register", a.handleRegisterShow)
	r.Post("/register", a.handleRegisterSubmit)
	r.Post("/logout", a.handleLogout)

	r.With(a.requireSignedIn, a.requireClient).Get("/listings/new", a.handleListingNewShow)
	r.With(a.requireSignedIn, a.requireClient).Post("/listings/new", a.handleListingCreate)
	r.With(a.requireSignedIn, a.requireClient).Get("/listings/mine", a.handleListingsMine)

	r.Get("/listings/{id}", a.handleListingDetail)
	r.Get("/listings/{id}/fragment", a.handleListingDetailFragment)
	r.With(a.requireSignedIn).Get("/listings/{id}/edit", a.handleListingEditShow)
	r.With(a.requireSignedIn).Post("/listings/{id}/edit", a.handleListingEditSubmit)

	r.With(a.requireSignedIn, a.requireFreelancer).Post("/listings/{id}/proposals", a.handleProposalCreate)
	r.With(a.requireSignedIn).Post("/listings/{id}/messages", a.handleMessageCreate)

	r.With(a.requireSignedIn).Post("/proposals/{id}/accept", a.handleProposalAccept)
	r.With(a.requireSignedIn).Post("/proposals/{id}/reject", a.handleProposalReject)
	r.With(a.requireSignedIn, a.requireFreelancer).Get("/proposals/mine", a.handleProposalsMine)

	root.Mount("/", r)
	return root
}
