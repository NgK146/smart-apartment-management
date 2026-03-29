using System.Text.Json;

namespace ICitizen.Infrastructure.Weather;

public class OpenWeatherService : IWeatherService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;

    public OpenWeatherService(HttpClient httpClient, IConfiguration config)
    {
        _httpClient = httpClient;
        _config = config;
    }

    public async Task<(string Weather, int Temperature)> GetCurrentWeatherAsync()
    {
        try
        {
            var city = _config["WeatherSettings:City"] ?? "Ho Chi Minh";
            var apiKey = _config["WeatherSettings:ApiKey"];

            if (string.IsNullOrEmpty(apiKey))
            {
                // Fallback to default weather if no API key
                return ("sunny", 32);
            }

            var url = $"https://api.openweathermap.org/data/2.5/weather?q={city}&appid={apiKey}&units=metric";

            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadAsStringAsync();

            using var doc = JsonDocument.Parse(json);
            var temp = doc.RootElement.GetProperty("main").GetProperty("temp").GetDouble();
            var main = doc.RootElement.GetProperty("weather")[0].GetProperty("main").GetString()?.ToLowerInvariant();

            string weather = main switch
            {
                "rain" => "rainy",
                "drizzle" => "rainy",
                "thunderstorm" => "rainy",
                "clouds" => "cloudy",
                "clear" => "sunny",
                _ => "unknown"
            };

            return (weather, (int)Math.Round(temp));
        }
        catch
        {
            // Fallback to default weather on error
            return ("sunny", 32);
        }
    }
}

