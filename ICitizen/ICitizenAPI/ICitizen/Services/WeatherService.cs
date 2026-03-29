using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json.Linq;

namespace ICitizen.Services;

/// <summary>
/// Lấy thời tiết thực tế từ OpenWeatherMap.
/// Cấu hình được đọc từ appsettings.json
/// </summary>
public sealed class WeatherService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;

    public WeatherService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _apiKey = configuration["WeatherSettings:ApiKey"] ?? throw new ArgumentNullException("WeatherSettings:ApiKey is required");
    }

    public async Task<string> GetWeatherDescriptionAsync(string city)
    {
        try
        {
            var url =
                $"https://api.openweathermap.org/data/2.5/weather?q={city}&appid={_apiKey}&units=metric&lang=vi";
            var response = await _httpClient.GetStringAsync(url);
            var json = JObject.Parse(response);

            var temp = json["main"]?["temp"]?.ToString() ?? "25";
            var desc = json["weather"]?[0]?["description"]?.ToString() ?? "mát mẻ";

            return $"Nhiệt độ {temp}°C, {desc}";
        }
        catch
        {
            return "Không lấy được thời tiết, giả định là Mát mẻ, 25°C";
        }
    }

    /// <summary>
    /// Lấy thời tiết theo tọa độ GPS (lat/lng).
    /// </summary>
    public async Task<string> GetWeatherAsync(double lat, double lng)
    {
        try
        {
            var url = $"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lng}&appid={_apiKey}&units=metric&lang=vi";
            var response = await _httpClient.GetStringAsync(url);
            var json = JObject.Parse(response);
            var temp = json["main"]?["temp"]?.ToString() ?? "25";
            var desc = json["weather"]?[0]?["description"]?.ToString() ?? "mát mẻ";
            return $"{temp}°C, {desc}";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Weather Error] {ex.Message}");
            return "25°C, Có mây (Giả lập do lỗi API)";
        }
    }
}
