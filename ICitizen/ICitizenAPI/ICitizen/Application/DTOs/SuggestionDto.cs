namespace ICitizen.Application.DTOs;

public class SuggestionDto
{
    public string Code { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Tags { get; set; } = string.Empty;

    // Điểm nội bộ dùng để debug / test
    public double Score { get; set; }

    // Mức độ ưu tiên 1–5 (để sort / hiển thị)
    public int Priority { get; set; }
}

