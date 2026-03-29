using ICitizen.Application.DTOs;

namespace ICitizen.Application.Interfaces;

public interface ISuggestionService
{
    Task<List<SuggestionDto>> GetSuggestionsAsync(Guid residentId);
}

