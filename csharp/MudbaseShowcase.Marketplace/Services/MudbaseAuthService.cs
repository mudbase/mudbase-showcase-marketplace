using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Mudbase.Sdk.Api;
using Mudbase.Sdk.Model;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Options;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>
/// Everything auth-related: bootstrapping a guest anonymous session so the listings feed can be
/// browsed without signing in, login, session refresh, and logout. No self-registration UI - the
/// generated SDK's IAuthenticationApi only exposes RegisterLocalUserAsync (which calls the
/// project's single default-role endpoint POST /api/auth/local/register); there is no generated
/// method for the per-role POST /api/auth/local/signup/:role path this project's two custom roles
/// ("client"/"freelancer") actually require (confirmed by reading
/// mudbase-sdk/csharp/src/Mudbase.Sdk/Api/AuthenticationApi.cs directly). This is the identical,
/// already-documented scope decision the sibling mudbase-showcase-events/csharp port made - the
/// task's two demo accounts already exist and are pre-verified, so this reference app's /Login
/// page offers manual email/password sign-in plus two "Sign in as..." quick-fill buttons and
/// nothing more.
///
/// Every call here goes through the generated SDK directly - no raw-HttpClient workarounds.
/// </summary>
public sealed class MudbaseAuthService
{
    private readonly IAuthenticationApi _authApi;
    private readonly MudbaseSessionAccessor _session;
    private readonly MudbaseOptions _options;
    private readonly ILogger<MudbaseAuthService> _logger;

    public MudbaseAuthService(
        IAuthenticationApi authApi,
        MudbaseSessionAccessor session,
        IOptions<MudbaseOptions> options,
        ILogger<MudbaseAuthService> logger)
    {
        _authApi = authApi;
        _session = session;
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>
    /// Guest browsing with no signup: an anonymous session lets the listings feed's
    /// "authenticated"-role read permission resolve without forcing signup - mirrors the
    /// MudbaseProvider effect in web/src/lib/mudbase-provider.tsx and the identical bootstrap
    /// already established in the ecommerce/social C# ports. Posting listings, submitting
    /// proposals, accepting/rejecting proposals, and messaging still require a real, role-carrying
    /// "client"/"freelancer" account - see Rbac and each page handler's own guard. Called once per
    /// browser session by Infrastructure/EnsureMudbaseSessionMiddleware.
    /// </summary>
    public async Task EnsureAnonymousSessionAsync(CancellationToken cancellationToken)
    {
        if (_session.HasToken)
        {
            return;
        }

        try
        {
            ICreateAnonymousSessionApiResponse response =
                await _authApi.CreateAnonymousSessionAsync(new CreateAnonymousSessionRequest(_options.ProjectId), cancellationToken);

            if (response.TryOk(out CreateAnonymousSession200Response? body) && body?.Token is { Length: > 0 } token)
            {
                _session.SetTokens(token, body.RefreshToken);
                await RefreshSessionAsync(cancellationToken);
            }
            else
            {
                _logger.LogWarning("Anonymous Mudbase session bootstrap failed with status {StatusCode}", response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Anonymous Mudbase session bootstrap could not reach Mudbase");
        }
    }

    public async Task<AuthOutcome> LoginAsync(string email, string password, CancellationToken cancellationToken)
    {
        LoginLocalUserRequest request = new(email, password, _options.ProjectId);
        ILoginLocalUserApiResponse response = await _authApi.LoginLocalUserAsync(request, cancellationToken);

        if (!response.TryOk(out LoginLocalUser200Response? body) || body?.Token is not { Length: > 0 } token)
        {
            return AuthOutcome.Failure(MudbaseApiException.From(response).Message);
        }

        _session.SetTokens(token, body.RefreshToken);
        await RefreshSessionAsync(cancellationToken);
        return AuthOutcome.Success();
    }

    /// <summary>
    /// Fetches the full, authoritative session user (including customRole and isAnonymous, which
    /// the login/anonymous-bootstrap responses' typed models don't expose) and caches it in
    /// session state. Call after every token change (login, refresh, anonymous bootstrap) -
    /// mirrors refreshSession() in web/src/lib/mudbase-provider.tsx.
    /// </summary>
    public async Task RefreshSessionAsync(CancellationToken cancellationToken)
    {
        if (!_session.HasToken)
        {
            _session.ClearUser();
            return;
        }

        IGetLocalSessionApiResponse response = await _authApi.GetLocalSessionAsync(_options.ProjectId, cancellationToken);

        if (!response.TryOk(out GetLocalSession200Response? body) || body?.User is not JsonElement userElement)
        {
            _session.ClearToken();
            _session.ClearUser();
            return;
        }

        MudbaseSessionUser? user = JsonSerializer.Deserialize<MudbaseSessionUser>(userElement.GetRawText(), MudbaseJson.Options);
        _session.SetUser(user ?? new MudbaseSessionUser());
    }

    public async Task LogoutAsync(CancellationToken cancellationToken)
    {
        if (_session.HasToken)
        {
            try
            {
                await _authApi.LogoutLocalUserAsync(cancellationToken);
            }
            catch (HttpRequestException ex)
            {
                // Best-effort: the browser's session is cleared regardless so the user is signed
                // out locally even if Mudbase couldn't be reached to revoke server-side.
                _logger.LogWarning(ex, "Mudbase logout call failed; clearing local session anyway");
            }
        }

        _session.ClearToken();
        _session.ClearUser();
    }
}
