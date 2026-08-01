using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Services;

namespace MudbaseShowcase.Marketplace.Pages.Listings;

/// <summary>Client-only: post a new listing. Mirrors web/src/app/listings/new/page.tsx.</summary>
public sealed class NewModel : PageModel
{
    private readonly ListingsService _listings;
    private readonly MudbaseSessionAccessor _session;

    public NewModel(ListingsService listings, MudbaseSessionAccessor session)
    {
        _listings = listings;
        _session = session;
    }

    [BindProperty]
    public ListingInput Input { get; set; } = new();

    public string? SubmitError { get; private set; }

    public IActionResult OnGet()
    {
        if (_session.CurrentUser is not { IsClient: true })
        {
            return RedirectToPage("/Index");
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not { IsClient: true })
        {
            return RedirectToPage("/Index");
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        try
        {
            ListingDocument created = await _listings.CreateAsync(
                Input.Title, Input.Description, Input.Budget, Input.Category, user.Id, user.DisplayName, cancellationToken);
            return RedirectToPage("/Listings/Detail", new { id = created.Id });
        }
        catch (MudbaseApiException ex)
        {
            SubmitError = "Couldn't post this listing. Please try again. (" + ex.Message + ")";
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
    }
}
