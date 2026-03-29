using System.Net.Http.Headers;
using System.Text;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace ICitizen.Services;

/// <summary>
/// Gọi Groq AI (Llama model) để sinh gợi ý thông minh - miễn phí và nhanh.
/// Cấu hình được đọc từ appsettings.json
/// </summary>
public sealed class GroqService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;

    public GroqService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Groq:ApiKey"] ?? throw new ArgumentNullException("Groq:ApiKey is required");
        _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
    }

    public async Task<string> AskAiAsync(string weather, string places, string interest)
    {
        var url = "https://api.groq.com/openai/v1/chat/completions";
        var prompt = $@"
Bạn là trợ lý ảo SmartHome.
- Thời tiết: {weather}
- Địa điểm gần đây: {places}
- Sở thích user: {interest}
Nhiệm vụ: Gợi ý 1 hoạt động cụ thể tại 1 trong các địa điểm trên. Ngắn gọn, hài hước (dưới 50 từ).";

        var payload = new
        {
            model = "llama3-8b-8192", // Model miễn phí siêu nhanh
            messages = new[] { new { role = "user", content = prompt } }
        };

        try
        {
            var content = new StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync(url, content);
            var resString = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                Console.WriteLine($"[Groq Error] Status: {response.StatusCode}, Response: {resString}");
                // Fallback khi API không hoạt động
                return $"Dựa trên thời tiết {weather.ToLower()} và sở thích '{interest}', bạn nên ghé một trong các địa điểm trên để thư giãn! ☕✨";
            }

            dynamic? data = JsonConvert.DeserializeObject(resString);
            if (data?.choices != null && data.choices.Count > 0)
            {
                return data.choices[0]?.message?.content?.ToString() ?? "AI không trả về kết quả.";
            }
            return "AI không trả về kết quả.";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Groq Error] Exception: {ex.Message}");
            return $"Dựa trên thời tiết {weather.ToLower()} và sở thích '{interest}', bạn nên ghé một trong các địa điểm trên để thư giãn! ☕✨";
        }
    }
}
