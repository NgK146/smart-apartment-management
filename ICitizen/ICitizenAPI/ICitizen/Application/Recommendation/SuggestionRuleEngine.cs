using System.Text.Json;
using ICitizen.Application.DTOs;
using ICitizen.Domain;

namespace ICitizen.Application.Recommendation;

public class SuggestionRuleEngine : ISuggestionRuleEngine
{
    public List<SuggestionDto> BuildSuggestions(SuggestionContext ctx, List<Activity> activities)
    {
        var results = new List<(Activity activity, double score)>();

        var prefs = ParsePreferences(ctx.Resident.PreferredActivitiesJson);
        var hour = ctx.Now.Hour;
        var isWeekend = ctx.Now.DayOfWeek == DayOfWeek.Saturday || ctx.Now.DayOfWeek == DayOfWeek.Sunday;

        foreach (var a in activities)
        {
            double score = 0;

            // -------- 1. NỢ PHÍ --------
            if (ctx.UnpaidBillTypes.Contains("Service") && a.Code == "PAY_SERVICE_BILL")
                score += 100;

            if (ctx.UnpaidBillTypes.Contains("Electric") && a.Code == "PAY_ELECTRIC_BILL")
                score += 90;

            if (ctx.UnpaidBillTypes.Contains("Water") && a.Code == "PAY_WATER_BILL")
                score += 80;

            if (ctx.UnpaidBillTypes.Contains("Parking") && a.Code == "REGISTER_PARKING")
                score += 80;

            // -------- 2. SỞ THÍCH CÁ NHÂN --------
            foreach (var p in prefs)
            {
                if (!string.IsNullOrWhiteSpace(p) && a.Tags.Contains(p, StringComparison.OrdinalIgnoreCase))
                {
                    score += 20;
                }
            }

            // -------- 3. PHONG CÁCH SỐNG --------
            if (!string.IsNullOrEmpty(ctx.Resident.LifeStyle))
            {
                if (ctx.Resident.LifeStyle == "nang_dong" && a.Tags.Contains("suc_khoe"))
                    score += 15;

                if (ctx.Resident.LifeStyle == "gia_dinh" && a.Tags.Contains("hoat_dong_gia_dinh"))
                    score += 15;

                if (ctx.Resident.LifeStyle == "nguoi_gia" && a.Tags.Contains("nguoi_gia"))
                    score += 20;
            }

            // -------- 4. TUỔI TÁC --------
            if (ctx.Resident.Age.HasValue && ctx.Resident.Age >= 60 && a.Tags.Contains("nguoi_gia"))
                score += 15;

            // -------- 5. THỜI GIAN TRONG NGÀY --------
            if (hour >= 6 && hour < 12 && a.Tags.Contains("buoi_sang"))
                score += 20;
            else if (hour >= 6 && hour < 12 && (a.Tags.Contains("buoi_chieu") || a.Tags.Contains("buoi_toi")))
                score -= 10;

            if (hour >= 12 && hour < 18 && a.Tags.Contains("buoi_chieu"))
                score += 20;
            else if (hour >= 12 && hour < 18 && a.Tags.Contains("buoi_sang"))
                score -= 5;

            if (hour >= 18 && a.Tags.Contains("buoi_toi"))
                score += 20;
            else if (hour >= 18 && (a.Tags.Contains("buoi_sang") || a.Tags.Contains("buoi_chieu")))
                score -= 10;

            // -------- 6. CUỐI TUẦN --------
            if (isWeekend && a.Tags.Contains("cuoi_tuan"))
                score += 15;
            else if (!isWeekend && a.Tags.Contains("cuoi_tuan"))
                score -= 10;

            // -------- 7. THỜI TIẾT --------
            if (ctx.Weather == "rainy" && a.Tags.Contains("ngoai_troi"))
                score -= 40;

            if (ctx.Weather == "rainy" && a.Tags.Contains("trong_nha"))
                score += 10;

            if (ctx.Weather == "sunny" && a.Code == "GO_POOL_AFTERNOON" && ctx.Temperature >= 30)
                score += 30;

            if (ctx.Weather == "rainy" && a.Code == "ORDER_GROCERIES_ONLINE")
                score += 25;

            // -------- 8. SỰ KIỆN HÔM NAY --------
            if (ctx.TodayEvents.Any())
            {
                // event cho gia đình
                if (a.Code == "JOIN_WEEKEND_EVENT" &&
                    ctx.TodayEvents.Any(e => e.Tags.Contains("hoat_dong_gia_dinh")))
                {
                    score += 40;
                }

                // event cho trẻ em, ưu tiên cư dân gia đình
                if (a.Code == "JOIN_KIDS_WORKSHOP" &&
                    ctx.TodayEvents.Any(e => e.Tags.Contains("tre_em")) &&
                    ctx.Resident.LifeStyle == "gia_dinh")
                {
                    score += 50;
                }
            }

            // -------- 9. BẮT BUỘC --------
            if (a.Tags.Contains("bat_buoc"))
                score += 30;

            // ------ LỌC KẾT QUẢ -------
            if (score > 0)
            {
                results.Add((a, score));
            }
        }

        return results
            .OrderByDescending(x => x.score)
            .Take(10)
            .Select(x => new SuggestionDto
            {
                Code = x.activity.Code,
                Title = x.activity.Title,
                Description = x.activity.Description,
                Tags = x.activity.Tags,
                Score = x.score,
                Priority = MapScoreToPriority(x.score)
            })
            .ToList();
    }

    private static List<string> ParsePreferences(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new List<string>();
        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
        }
        catch
        {
            return new List<string>();
        }
    }

    private static int MapScoreToPriority(double score)
    {
        if (score >= 100) return 5;
        if (score >= 70) return 4;
        if (score >= 40) return 3;
        if (score >= 20) return 2;
        return 1;
    }
}

