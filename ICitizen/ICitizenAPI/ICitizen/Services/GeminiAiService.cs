using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace ICitizen.Services;

/// <summary>
/// Gọi Google Gemini để sinh gợi ý thông minh.
/// </summary>
public sealed class GeminiAiService
{
    private readonly HttpClient _httpClient;

    // TODO: nên đưa key vào Secret Manager / appsettings, tạm thời giữ theo yêu cầu người dùng.
    private const string ApiKey = "AIzaSyD-D-5xlmrJjN_XXdv0fBHslwxTIk9i5I4";

    public GeminiAiService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<string> GetRecommendationAsync(string weatherInfo, string userInterests)
    {
        // Thử gemini-1.5-flash-002 với v1beta (model mới nhất được hỗ trợ)
        var url =
            $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-002:generateContent?key={ApiKey}";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new[]
                    {
                        new
                        {
                            text =
                                $@"Bạn là quản gia SmartHome. 
Thời tiết: {weatherInfo}. 
Sở thích chủ nhà: {userInterests}.
Hãy đưa ra 1 lời gợi ý ngắn gọn (dưới 30 từ) và hài hước.
Và gợi ý 1 hành động thiết bị (Bật đèn/Bật nhạc/Bật điều hòa)."
                        }
                    }
                }
            }
        };

        var jsonContent =
            new StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync(url, jsonContent);
        var responseString = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"[Gemini Error] Status: {response.StatusCode}, Response: {responseString}");
            // Fallback: Trả về gợi ý giả lập khi API không hoạt động
            return $"Trời {weatherInfo.ToLower()}. Dựa trên sở thích '{userInterests}', bạn nên bật đèn và thư giãn với nhạc Lofi nhẹ nhàng. 🌙✨";
        }

        dynamic data = JsonConvert.DeserializeObject(responseString);

        try
        {
            if (data?.candidates == null || data.candidates.Count == 0)
            {
                Console.WriteLine($"[Gemini Error] No candidates in response: {responseString}");
                return "AI không trả về kết quả. Kiểm tra prompt hoặc API key.";
            }

            string result = data.candidates[0].content.parts[0].text;
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Gemini Error] Parse exception: {ex.Message}, Response: {responseString}");
            return $"Lỗi xử lý phản hồi AI: {ex.Message}";
        }
    }

    /// <summary>
    /// Nhận prompt toàn bộ (dùng cho tình huống tuỳ biến).
    /// </summary>
    public async Task<string> GetFromPromptAsync(string prompt)
    {
        // Thử gemini-1.5-flash-002 với v1beta (model mới nhất được hỗ trợ)
        var url =
            $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-002:generateContent?key={ApiKey}";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new[]
                    {
                        new
                        {
                            text = prompt
                        }
                    }
                }
            }
        };

        var jsonContent =
            new StringContent(JsonConvert.SerializeObject(payload), Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync(url, jsonContent);
        var responseString = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"[Gemini Error] Status: {response.StatusCode}, Response: {responseString}");
            // Fallback: Trả về gợi ý giả lập khi API không hoạt động
            return "Dựa trên vị trí và thời tiết hiện tại, bạn nên ghé một quán cà phê gần đây để thư giãn. Highlands Coffee ở ngay sảnh tòa nhà là lựa chọn tốt với không gian mát mẻ và đánh giá cao! ☕✨";
        }

        dynamic data = JsonConvert.DeserializeObject(responseString);

        try
        {
            if (data?.candidates == null || data.candidates.Count == 0)
            {
                Console.WriteLine($"[Gemini Error] No candidates in response: {responseString}");
                return "AI không trả về kết quả. Kiểm tra prompt hoặc API key.";
            }

            string result = data.candidates[0].content.parts[0].text;
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Gemini Error] Parse exception: {ex.Message}, Response: {responseString}");
            return $"Lỗi xử lý phản hồi AI: {ex.Message}";
        }
    }
}

