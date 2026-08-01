package server

import (
	"log"
	"net/http"
	"net/mail"
	"net/url"

	"github.com/mudbase/mudbase-showcase-marketplace/go/internal/mbase"
)

// LoginData is the /login page's content payload.
type LoginData struct {
	Base
	Redirect string
}

func (a *App) handleLoginShow(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	if data.IsSignedIn() {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	view := LoginData{
		Base:     a.baseView(r, "Sign in"),
		Redirect: r.URL.Query().Get("redirect"),
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "login.html", view)
}

// loginError redirects back to /login preserving both the flash message and any pending
// post-login redirect target.
func loginError(w http.ResponseWriter, r *http.Request, redirect, message string) {
	q := url.Values{"error": {message}}
	if redirect != "" {
		q.Set("redirect", redirect)
	}
	http.Redirect(w, r, "/login?"+q.Encode(), http.StatusSeeOther)
}

func (a *App) handleLoginSubmit(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	email := r.FormValue("email")
	password := r.FormValue("password")
	redirect := r.FormValue("redirect")

	if _, err := mail.ParseAddress(email); err != nil {
		loginError(w, r, redirect, "Enter a valid email address.")
		return
	}
	if password == "" {
		loginError(w, r, redirect, "Password is required.")
		return
	}

	auth, err := a.mudbase.Login(r.Context(), email, password)
	if err != nil {
		loginError(w, r, redirect, mbase.FriendlyMessage(err))
		return
	}

	data := sessionFrom(r)
	data.SetUser(auth)
	if err := data.Save(w, r); err != nil {
		a.serverError(w, r, err)
		return
	}

	target := "/"
	if auth.User.CustomRole == "client" {
		target = "/listings/mine"
	}
	if redirect != "" {
		target = redirect
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

// RegisterData is the /register page's content payload.
type RegisterData struct {
	Base
}

func (a *App) handleRegisterShow(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	if data.IsSignedIn() {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	view := RegisterData{Base: a.baseView(r, "Create your account")}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "register.html", view)
}

// validateRegisterForm mirrors the reference web app's RegisterForm.tsx zod schema.
func validateRegisterForm(firstName, lastName, email, password, role string, agreedToTerms bool) string {
	if firstName == "" {
		return "First name is required."
	}
	if lastName == "" {
		return "Last name is required."
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return "Enter a valid email address."
	}
	if len(password) < 8 {
		return "Password must be at least 8 characters."
	}
	if role != "client" && role != "freelancer" {
		return "Choose whether you're hiring or looking for work."
	}
	if !agreedToTerms {
		return "You must agree to the Terms of Service and Privacy Policy."
	}
	return ""
}

func (a *App) handleRegisterSubmit(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	firstName := r.FormValue("firstName")
	lastName := r.FormValue("lastName")
	email := r.FormValue("email")
	password := r.FormValue("password")
	role := r.FormValue("role")
	agreedToTerms := r.FormValue("agreedToTerms") == "on"

	if message := validateRegisterForm(firstName, lastName, email, password, role, agreedToTerms); message != "" {
		redirectWithError(w, r, "/register", message)
		return
	}

	auth, err := a.mudbase.Register(r.Context(), mbase.RegisterRole(role), email, password, firstName, lastName, agreedToTerms)
	if err != nil {
		redirectWithError(w, r, "/register", mbase.FriendlyMessage(err))
		return
	}

	data := sessionFrom(r)
	data.SetUser(auth)
	if err := data.Save(w, r); err != nil {
		a.serverError(w, r, err)
		return
	}

	target := "/"
	if role == "client" {
		target = "/listings/mine"
	} else {
		target = "/proposals/mine"
	}
	http.Redirect(w, r, target, http.StatusSeeOther)
}

// handleLogout revokes the session's token server-side (best-effort - a failure here shouldn't
// block the visitor from being signed out locally) and clears the local session identity, letting
// the session middleware re-establish a fresh anonymous session on the very next request.
func (a *App) handleLogout(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	if token := data.AccessToken(); token != "" && !data.IsAnonymous() {
		if err := a.mudbase.Logout(r.Context(), token); err != nil {
			log.Printf("server: logout: %v", mbase.FriendlyMessage(err))
		}
	}
	data.ClearUser()
	if err := data.Save(w, r); err != nil {
		a.serverError(w, r, err)
		return
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}
