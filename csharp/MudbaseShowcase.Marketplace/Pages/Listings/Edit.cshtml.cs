using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages.Listings;

/// <summary>
/// Client, owner only: edit title/description/budget/category/status. Mirrors
/// web/src/app/listings/[id]/edit/page.tsx.
///
/// SECURITY: both OnGetAsync and OnPostAsync re-fetch the listing from Mudbase and check
/// `listing.ClientId == user.Id` before allowing anything - the id in the route is not trusted as
/// proof of ownership by itself. This mirrors the ownership re-derivation discipline the sibling
/// Events C# port's csharp-reviewer pass required after finding a real IDOR (a handler that
/// trusted a hidden form field instead of re-checking ownership against the fetched document).
/// </summary>
public sealed class EditModel : PageModel
{
    private readonly ListingsService _listings;
    private readonly MudbaseSessionAccessor _session;

    public EditModel(ListingsService listings, MudbaseSessionAccessor session)
    {
        _listings = listings;
        _session = session;
    }

    [BindProperty]
    public ListingInput Input { get; set; } = new();

    public bool IsNotFound { get; private set; }

    public bool IsForbidden { get; private set; }

    public string? SubmitError { get; private set; }

    public async Task<IActionResult> OnGetAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;

        ListingDocument? listing;
        try
        {
            listing = await _listings.GetAsync(id, cancellationToken);
        }
        catch (MudbaseApiException)
        {
            IsNotFound = true;
            return Page();
        }

        if (listing is null)
        {
            IsNotFound = true;
            return Page();
        }

        if (user is not { IsClient: true } || listing.ClientId != user.Id)
        {
            IsForbidden = true;
            return Page();
        }

        Input = new ListingInput
        {
            Title = listing.Title,
            Description = listing.Description,
            Budget = listing.Budget,
            Category = listing.Category ?? string.Empty,
            Status = listing.Status,
        };

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(string id, CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;

        // Re-fetch and re-verify ownership on every POST too - the id came from the route, not
        // from anything this handler can trust without checking against the document itself.
        ListingDocument? listing;
        try
        {
            listing = await _listings.GetAsync(id, cancellationToken);
        }
        catch (MudbaseApiException)
        {
            IsNotFound = true;
            return Page();
        }

        if (listing is null)
        {
            IsNotFound = true;
            return Page();
        }

        if (user is not { IsClient: true } || listing.ClientId != user.Id)
        {
            IsForbidden = true;
            return Page();
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        // The <select> only ever renders ListingStatus.All's options, but a POST body is fully
        // client-controlled - re-validate the submitted value server-side too, the same discipline
        // applied to ownership above, rather than trusting the dropdown's own constraint.
        if (!ListingStatus.All.Contains(Input.Status))
        {
            ModelState.AddModelError("Input.Status", "Select a valid status.");
            return Page();
        }

        try
        {
            await _listings.UpdateAsync(id, Input.Title, Input.Description, Input.Budget, Input.Category, Input.Status, cancellationToken);
            return RedirectToPage("/Listings/Detail", new { id });
        }
        catch (MudbaseApiException ex)
        {
            SubmitError = "Couldn't save this listing. Please try again. (" + ex.Message + ")";
            return Page();
        }
    }

    public sealed class ListingInput
    {
        [Required(ErrorMessage = "Title is required"), StringLength(120, MinimumLength = 3, ErrorMessage = "Title must be 3-120 characters")]
        public string Title { get; set; } = string.Empty;

        [Required(ErrorMessage = "Description is required"), MinLength(20, ErrorMessage = "Description must be at least 20 characters")]
        public string Description { get; set; } = string.Empty;

        [Range(typeof(decimal), "0.01", "79228162514264337593543950335", ErrorMessage = "Budget must be greater than 0")]
        public decimal Budget { get; set; }

        [StringLength(60, ErrorMessage = "Category is too long")]
        public string? Category { get; set; }

        [Required]
        public string Status { get; set; } = ListingStatus.Open;
    }
}
