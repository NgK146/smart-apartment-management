namespace ICitizen.Models;

public class PlaceInfo
{
    public string Name { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public double Lat { get; set; }
    public double Lng { get; set; }
}

public class AiResponse
{
    public string WeatherInfo { get; set; } = string.Empty;
    public List<PlaceInfo> Places { get; set; } = new();
    public string AiAdvice { get; set; } = string.Empty;
}





