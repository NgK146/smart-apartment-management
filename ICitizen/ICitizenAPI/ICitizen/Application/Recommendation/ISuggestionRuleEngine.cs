using ICitizen.Application.DTOs;
using ICitizen.Domain;

namespace ICitizen.Application.Recommendation;

public interface ISuggestionRuleEngine
{
    List<SuggestionDto> BuildSuggestions(SuggestionContext ctx, List<Activity> activities);
}

