using ICitizen.Domain;

namespace ICitizen.Application.Recommendation;

public class SuggestionContext
{
    public ResidentProfile Resident { get; set; } = default!;

    public string Weather { get; set; } = "unknown"; // "sunny", "rainy", "cloudy"
    public int Temperature { get; set; }
    public DateTime Now { get; set; }

    // Nợ phí
    public List<string> UnpaidBillTypes { get; set; } = new();

    // Sự kiện
    public List<CommunityEvent> TodayEvents { get; set; } = new();
}

