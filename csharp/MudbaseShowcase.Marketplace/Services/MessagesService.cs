using Microsoft.Extensions.Options;
using MudbaseShowcase.Marketplace.Models;
using MudbaseShowcase.Marketplace.Options;

namespace MudbaseShowcase.Marketplace.Services;

/// <summary>Collection-specific wrapper over MudbaseDataService for `messages`. Mirrors MessageThread.tsx.</summary>
public sealed class MessagesService
{
    private readonly MudbaseDataService _data;
    private readonly MudbaseOptions _options;

    public MessagesService(MudbaseDataService data, IOptions<MudbaseOptions> options)
    {
        _data = data;
        _options = options.Value;
    }

    /// <summary>Every message on a listing's thread, oldest first - mirrors MessageThread.tsx's `sort: "createdAt"`.</summary>
    public Task<MudbaseListResult<MessageDocument>> ListForListingAsync(string listingId, CancellationToken cancellationToken = default) =>
        _data.ListAsync<MessageDocument>(
            _options.MessagesCollectionId,
            new Dictionary<string, object?> { ["listingId"] = listingId },
            sort: "createdAt", limit: 100, cancellationToken: cancellationToken);

    public Task<MessageDocument> CreateAsync(string listingId, string senderId, string senderName, string content, CancellationToken cancellationToken = default)
    {
        Dictionary<string, object?> data = new()
        {
            ["listingId"] = listingId,
            ["senderId"] = senderId,
            ["senderName"] = senderName,
            ["content"] = content,
        };
        return _data.CreateAsync<MessageDocument>(_options.MessagesCollectionId, data, cancellationToken);
    }
}
