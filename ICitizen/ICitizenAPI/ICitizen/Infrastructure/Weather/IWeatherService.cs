namespace ICitizen.Infrastructure.Weather;

public interface IWeatherService
{
    Task<(string Weather, int Temperature)> GetCurrentWeatherAsync();
}

