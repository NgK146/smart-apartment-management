using Microsoft.EntityFrameworkCore;
using ICitizen.Application.Interfaces;
using ICitizen.Domain;
using ICitizen.Data;

namespace ICitizen.Infrastructure.Repositories;

public class EfSuggestionRepository : ISuggestionRepository
{
    private readonly ApplicationDbContext _db;

    public EfSuggestionRepository(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<ResidentProfile?> GetResidentAsync(Guid residentId)
    {
        return await _db.ResidentProfiles
            .Include(r => r.Apartment)
            .FirstOrDefaultAsync(r => r.Id == residentId);
    }

    public async Task<List<Activity>> GetActivitiesAsync()
    {
        return await _db.Activities.ToListAsync();
    }

    public async Task<List<Bill>> GetUnpaidBillsAsync(Guid residentId)
    {
        return await _db.Bills
            .Where(b => b.ResidentProfileId == residentId && !b.IsPaid)
            .ToListAsync();
    }

    public async Task<List<CommunityEvent>> GetTodayEventsForResidentAsync(ResidentProfile resident, DateTime today)
    {
        var date = today.Date;
        var building = resident.Building ?? (resident.Apartment != null ? resident.Apartment.Building : "") ?? "";
        var floor = resident.Floor ?? (resident.Apartment != null ? resident.Apartment.Floor : 0);

        return await _db.CommunityEvents
            .Where(e => e.StartTime.Date == date
                        && e.Building == building
                        && (e.Floor == null || e.Floor == floor))
            .ToListAsync();
    }
}

