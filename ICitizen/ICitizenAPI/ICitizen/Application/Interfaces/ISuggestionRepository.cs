using ICitizen.Domain;

namespace ICitizen.Application.Interfaces;

public interface ISuggestionRepository
{
    Task<ResidentProfile?> GetResidentAsync(Guid residentId);
    Task<List<Activity>> GetActivitiesAsync();
    Task<List<Bill>> GetUnpaidBillsAsync(Guid residentId);
    Task<List<CommunityEvent>> GetTodayEventsForResidentAsync(ResidentProfile resident, DateTime today);
}

