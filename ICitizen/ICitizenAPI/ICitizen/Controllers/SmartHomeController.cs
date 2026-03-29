using ICitizen.Models;
using ICitizen.Services;
using Microsoft.AspNetCore.Mvc;

namespace ICitizen.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class SmartHomeController : ControllerBase
{
    private readonly WeatherService _weatherService;
    private readonly GroqService _groqService;
    private readonly OsmService _osmService;
    private readonly BlockchainService _blockchainService;

    public SmartHomeController(WeatherService weather, GroqService groq, OsmService osm, BlockchainService blockchain)
    {
        _weatherService = weather;
        _groqService = groq;
        _osmService = osm;
        _blockchainService = blockchain;
    }

    [HttpGet("ask-ai")]
    public async Task<IActionResult> AskAi([FromQuery] string city = "Ho Chi Minh")
    {
        var weather = await _weatherService.GetWeatherDescriptionAsync(city);
        // TODO: thay interests bằng dữ liệu thực từ DB nếu cần
        var interests = "Thích nghe nhạc Lofi, uống trà, ghét tiếng ồn";
        // Fallback response khi không có location
        var advice = $"Trời {weather.ToLower()}. Dựa trên sở thích '{interests}', bạn nên bật đèn và thư giãn với nhạc Lofi nhẹ nhàng. 🌙✨";

        return Ok(new
        {
            weather_info = weather,
            ai_advice = advice
        });
    }

    // API điều khiển thiết bị thật (mock) + ghi log lên Blockchain
    [HttpPost("control-device")]
    public async Task<IActionResult> ControlDevice([FromBody] DeviceCommand cmd)
    {
        Console.WriteLine($"[IOT LOG] Đang thực hiện lệnh: {cmd.Action} cho thiết bị {cmd.DeviceName}");
        
        // Ghi log lên Ganache Blockchain
        var txHash = await _blockchainService.WriteLogAsync(cmd.DeviceName, cmd.Action);
        
        return Ok(new 
        { 
            message = $"Đã {cmd.Action} {cmd.DeviceName} thành công!",
            blockchain_tx = txHash
        });
    }

    /// <summary>
    /// Test endpoint để kiểm tra kết nối Ganache Blockchain
    /// </summary>
    [HttpGet("test-blockchain")]
    public async Task<IActionResult> TestBlockchain()
    {
        try
        {
            var txHash = await _blockchainService.WriteLogAsync("TestDevice", "TestAction");
            
            return Ok(new
            {
                success = true,
                message = "Blockchain đã hoạt động! ✅",
                transaction_hash = txHash,
                ganache_url = "http://127.0.0.1:7545",
                contract_address = "0xd9145CCE52D386f254917e481eB44e9943F39138"
            });
        }
        catch (Exception ex)
        {
            return BadRequest(new
            {
                success = false,
                message = "Lỗi kết nối Blockchain ❌",
                error = ex.Message,
                troubleshooting = new[]
                {
                    "1. Kiểm tra Ganache đang chạy trên http://127.0.0.1:7545",
                    "2. Kiểm tra contract đã deploy đúng địa chỉ: 0xd9145CCE52D386f254917e481eB44e9943F39138",
                    "3. Kiểm tra private key đúng với account trong Ganache"
                }
            });
        }
    }

    /// <summary>
    /// Endpoint mới: Lấy gợi ý AI dựa trên vị trí GPS thực tế.
    /// </summary>
    [HttpGet("advice")]
    public async Task<IActionResult> GetSmartAdvice([FromQuery] double lat, [FromQuery] double lng)
    {
        // 1. Giả lập lấy sở thích từ DB (Bạn có thể Query SQL ở đây)
        const string interest = "coffee"; // Thích cà phê

        // 2. Chạy song song lấy thông tin môi trường
        var taskWeather = _weatherService.GetWeatherAsync(lat, lng);
        var taskPlacesList = _osmService.GetNearbyPlacesListAsync(lat, lng, interest);
        await Task.WhenAll(taskWeather, taskPlacesList);

        // 3. Chuyển List thành text để gửi cho AI đọc
        string placesTextForAi = string.Join("\n", taskPlacesList.Result.Select(p => $"- {p.Name}"));

        // 4. Hỏi AI
        var aiAdvice = await _groqService.AskAiAsync(taskWeather.Result, placesTextForAi, interest);

        return Ok(new AiResponse
        {
            WeatherInfo = taskWeather.Result,
            Places = taskPlacesList.Result,
            AiAdvice = aiAdvice
        });
    }

    /// <summary>
    /// Endpoint cũ (giữ lại để tương thích với Flutter code hiện tại).
    /// </summary>
    [HttpGet("ask-ai-location")]
    public async Task<IActionResult> AskAiLocation([FromQuery] double lat, [FromQuery] double lng)
    {
        // Giả lập sở thích
        const string userInterest = "coffee";

        // 1. Địa điểm gần (OSM)
        var nearbyPlaces = await _osmService.GetNearbyPlacesAsync(lat, lng, userInterest);

        // 2. Thời tiết theo GPS
        var weather = await _weatherService.GetWeatherAsync(lat, lng);

        // 3. Hỏi Groq AI
        var advice = await _groqService.AskAiAsync(weather, nearbyPlaces, userInterest);

        return Ok(new
        {
            place_data = nearbyPlaces,
            ai_advice = advice
        });
    }
}

public sealed class DeviceCommand
{
    public string DeviceName { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
}

