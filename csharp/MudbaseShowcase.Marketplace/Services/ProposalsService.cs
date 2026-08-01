using Microsoft.Extensions.Options;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Options;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>Collection-specific wrapper over MudbaseDataService for `proposals`. Mirrors ProposalForm.tsx/ProposalList.tsx and web/src/app/proposals/page.tsx.</summary>
public sealed class ProposalsService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public ProposalsService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    public Task<ProposalDocument?> GetAsync(string id, CancellationToken cancellationToken = default) =>
        _data.GetAsync<ProposalDocument>(_options.ProposalsCollectionId, id, cancellationToken);

    /// <summary>Every proposal submitted against one listing, most recent first - shown to the owning client on the listing detail page.</summary>
    public Task<MudbaseListResult<ProposalDocument>> ListForListingAsync(string listingId, CancellationToken cancellationToken = default) =>
        _data.ListAsync<ProposalDocument>(
            _options.ProposalsCollectionId,
            new Dictionary<string, object?> { ["listingId"] = listingId },
            sort: "-createdAt", limit: 100, cancellationToken: cancellationToken);

    /// <summary>The (at most one) accepted proposal on a listing - determines who besides the client can see and use the message thread. See plan/build-plan.md "Messaging visibility".</summary>
    public async Task<ProposalDocument?> GetAcceptedAsync(string listingId, CancellationToken cancellationToken = default)
    {
        MudbaseListResult<ProposalDocument> result = await _data.ListAsync<ProposalDocument>(
            _options.ProposalsCollectionId,
            new Dictionary<string, object?> { ["listingId"] = listingId, ["status"] = ProposalStatus.Accepted },
            sort: "-createdAt", limit: 1, cancellationToken: cancellationToken);
        return result.Items.FirstOrDefault();
    }

    /// <summary>A freelancer's own proposal on a specific listing, if any - determines whether the listing detail page shows the submission form or the existing status.</summary>
    public async Task<ProposalDocument?> GetOwnAsync(string listingId, string freelancerId, CancellationToken cancellationToken = default)
    {
        MudbaseListResult<ProposalDocument> result = await _data.ListAsync<ProposalDocument>(
            _options.ProposalsCollectionId,
            new Dictionary<string, object?> { ["listingId"] = listingId, ["freelancerId"] = freelancerId },
            sort: "-createdAt", limit: 1, cancellationToken: cancellationToken);
        return result.Items.FirstOrDefault();
    }

    /// <summary>A freelancer's own proposals across every listing, most recent first.</summary>
    public Task<MudbaseListResult<ProposalDocument>> ListMineAsync(string freelancerId, int page, int limit, CancellationToken cancellationToken = default) =>
        _data.ListAsync<ProposalDocument>(
            _options.ProposalsCollectionId,
            new Dictionary<string, object?> { ["freelancerId"] = freelancerId },
            sort: "-createdAt", page: page, limit: limit, cancellationToken: cancellationToken);

    /// <summary>One batched query for proposal counts across every listing id supplied, instead of an N+1 query per listing - mirrors web/src/app/listings/mine/page.tsx.</summary>
    public async Task<IReadOnlyDictionary<string, int>> CountByListingAsync(IReadOnlyList<string> listingIds, CancellationToken cancellationToken = default)
    {
        if (listingIds.Count == 0) return new Dictionary<string, int>();

        MudbaseListResult<ProposalDocument> result = await _data.ListAsync<ProposalDocument>(
            _options.ProposalsCollectionId,
            new Dictionary<string, object?> { ["listingId"] = new Dictionary<string, object?> { ["$in"] = listingIds } },
            sort: "-createdAt", limit: 100, cancellationToken: cancellationToken);

        Dictionary<string, int> counts = new();
        foreach (ProposalDocument proposal in result.Items)
        {
            counts[proposal.ListingId] = counts.GetValueOrDefault(proposal.ListingId) + 1;
        }
        return counts;
    }

    public Task<ProposalDocument> CreateAsync(
        string listingId, string freelancerId, string freelancerName, string coverLetter, decimal proposedRate, CancellationToken cancellationToken = default)
    {
        Dictionary<string, object?> data = new()
        {
            ["listingId"] = listingId,
            ["freelancerId"] = freelancerId,
            ["freelancerName"] = freelancerName,
            ["coverLetter"] = coverLetter,
            ["proposedRate"] = proposedRate,
            ["status"] = ProposalStatus.Pending,
        };
        return _data.CreateAsync<ProposalDocument>(_options.ProposalsCollectionId, data, cancellationToken);
    }

    public Task<ProposalDocument> SetStatusAsync(string id, string status, CancellationToken cancellationToken = default) =>
        _data.UpdateAsync<ProposalDocument>(_options.ProposalsCollectionId, id, new Dictionary<string, object?> { ["status"] = status }, cancellationToken);
}
