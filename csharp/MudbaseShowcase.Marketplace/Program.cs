using Microsoft.AspNetCore.HttpOverrides;
using Mudbase.Sdk.Client;
using Mudbase.Sdk.Extensions;
using MudbaseShowcase.Marketplace.Infrastructure;
using MudbaseShowcase.Marketplace.Options;
using MudbaseShowcase.Marketplace.Services;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// Bind once, up front, so both the strongly-typed IOptions<MudbaseOptions> (used throughout the
// app) and the plain values needed to configure HttpClient base addresses below come from the
// exact same "Mudbase" config section - see appsettings.Example.json for every key this needs.
MudbaseOptions mudbaseOptions = builder.Configuration.GetSection(MudbaseOptions.SectionName).Get<MudbaseOptions>() ?? new MudbaseOptions();
mudbaseOptions.Validate();
builder.Services.Configure<MudbaseOptions>(builder.Configuration.GetSection(MudbaseOptions.SectionName));

builder.Services.AddHttpContextAccessor();

// Server-side session - the Mudbase JWT lives here and is never exposed to client JS.
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(sessionOptions =>
{
    sessionOptions.Cookie.Name = "mudbase.showcase.marketplace.session";
    sessionOptions.Cookie.HttpOnly = true;
    sessionOptions.Cookie.IsEssential = true;
    sessionOptions.Cookie.SameSite = SameSiteMode.Lax;
    sessionOptions.IdleTimeout = TimeSpan.FromHours(4);
});

// Plain HttpClient for TokenRefreshHandler's own POST /api/auth/refresh call - deliberately
// outside the generated SDK's HttpClient pipeline (see TokenRefreshHandler) so a refresh call can
// never recursively trigger the same 401-retry handler it's part of.
builder.Services.AddHttpClient(HttpClientNames.MudbaseRaw, client => client.BaseAddress = new Uri(mudbaseOptions.BaseUrl));

// Wires up Mudbase.Sdk's generated Api classes (AuthenticationApi, DataApi, SearchApi, ...) via
// its own DI extensions. The SDK's token pipeline assumes one static token per app (fine for a
// server-to-server API key) - SessionBearerTokenProvider overrides that so each call resolves
// whichever JWT the *current* browser session's cookie points at. See SessionBearerTokenProvider
// for the full explanation.
builder.Host.ConfigureApi((_, apiOptions) =>
{
    // TokenRefreshHandler is attached to every one of the SDK's generated HttpClients here (this
    // callback runs once per Api's IHttpClientBuilder) so an expired access token is transparently
    // refreshed and the original request retried once, instead of surfacing a raw 401 to the page.
    apiOptions.AddApiHttpClients(
        client => client.BaseAddress = new Uri(mudbaseOptions.BaseUrl),
        httpClientBuilder => httpClientBuilder.AddHttpMessageHandler<TokenRefreshHandler>());

    // DataApi/AuthenticationApi/SearchApi's constructors require a TokenProvider<ApiKeyToken> even
    // though this app never calls an ApiKeyAuth-only endpoint (every call here goes through a
    // per-user Bearer JWT) - register a harmless placeholder so DI can resolve them.
    apiOptions.AddTokens(new ApiKeyToken("unused", ClientUtils.ApiKeyHeader.X_API_Key));

    apiOptions.UseProvider<SessionBearerTokenProvider, BearerToken>();
});

builder.Services.AddSingleton<MudbaseSessionAccessor>();
builder.Services.AddTransient<TokenRefreshHandler>();
builder.Services.AddScoped<MudbaseAuthService>();
builder.Services.AddScoped<MudbaseDataService>();
builder.Services.AddScoped<MudbaseSearchService>();
builder.Services.AddScoped<ListingsService>();
builder.Services.AddScoped<ProposalsService>();
builder.Services.AddScoped<MessagesService>();

builder.Services.AddRazorPages();

WebApplication app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
});

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseSession();
app.UseMiddleware<EnsureMudbaseSessionMiddleware>();

// No [Authorize]/ASP.NET Core identity here by design - auth state comes entirely from the
// Mudbase JWT cached in session (see MudbaseSessionAccessor), and page-level gating (client vs.
// freelancer vs. guest) is done explicitly in each PageModel's OnGet/OnPost, mirroring useAuth.ts's
// checks. Every mutating handler additionally re-derives ownership from the fetched document
// itself before calling Mudbase - see Services/Rbac.cs's doc comment. Neither of those is the real
// enforcement boundary - Mudbase's own collection permissions are.
app.MapRazorPages();

app.Run();
