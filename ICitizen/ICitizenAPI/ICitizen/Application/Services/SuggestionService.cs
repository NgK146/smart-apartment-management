using ICitizen.Application.DTOs;
using ICitizen.Application.Interfaces;
using ICitizen.Application.Recommendation;
using ICitizen.Infrastructure.Weather;

namespace ICitizen.Application.Services;

public class SuggestionService : ISuggestionService
{
    private readonly ISuggestionRepository _repo;
    private readonly IWeatherService _weatherService;
    private readonly ISuggestionRuleEngine _ruleEngine;

    public SuggestionService(
        ISuggestionRepository repo,
        IWeatherService weatherService,
        ISuggestionRuleEngine ruleEngine)
    {
        _repo = repo;
        _weatherService = weatherService;
        _ruleEngine = ruleEngine;
    }

    public async Task<List<SuggestionDto>> GetSuggestionsAsync(Guid residentId)
    {
        var resident = await _repo.GetResidentAsync(residentId);
        if (resident == null)
        {
            return new List<SuggestionDto>();
        }

        var now = DateTime.Now;
        var (weather, temp) = await _weatherService.GetCurrentWeatherAsync();

        var unpaidBills = await _repo.GetUnpaidBillsAsync(residentId);
        var events = await _repo.GetTodayEventsForResidentAsync(resident, now);
        var activities = await _repo.GetActivitiesAsync();

        var ctx = new SuggestionContext
        {
            Resident = resident,
            Weather = weather,
            Temperature = temp,
            Now = now,
            UnpaidBillTypes = unpaidBills
                .Select(b => b.Type)
                .Distinct()
                .ToList(),
            TodayEvents = events
        };

        return _ruleEngine.BuildSuggestions(ctx, activities);
    }
}

