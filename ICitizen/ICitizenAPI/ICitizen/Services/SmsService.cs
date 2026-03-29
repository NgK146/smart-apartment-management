using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ICitizen.Services;

/// <summary>
/// Service gửi SMS - Tích hợp với ESMS (Việt Nam) hoặc có thể mở rộng cho dịch vụ khác
/// </summary>
public class SmsService : ISmsService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmsService> _logger;
    private readonly HttpClient _httpClient;

    public SmsService(IConfiguration configuration, ILogger<SmsService> logger, IHttpClientFactory httpClientFactory)
    {
        _configuration = configuration;
        _logger = logger;
        _httpClient = httpClientFactory.CreateClient("SmsClient"); // Dùng named client với redirect enabled
    }

    public async Task<bool> SendSmsAsync(string phoneNumber, string message)
    {
        try
        {
            var provider = _configuration["Sms:Provider"] ?? "ESMS"; // Mặc định dùng ESMS
            var isEnabled = _configuration.GetValue<bool>("Sms:Enabled", true);

            // Nếu SMS bị tắt, chỉ log (để test)
            if (!isEnabled)
            {
                _logger.LogWarning("SMS đang bị tắt (Sms:Enabled = false). Chỉ log để test.");
                _logger.LogInformation("📱 SMS gửi đến {PhoneNumber}: {Message}", phoneNumber, message);
                await Task.Delay(500);
                return true;
            }

            // Format số điện thoại Việt Nam
            var formattedPhone = FormatPhoneNumber(phoneNumber);

            // Gửi SMS theo provider
            bool result = provider.ToUpper() switch
            {
                "ESMS" => await SendViaESMS(formattedPhone, message),
                "BRANDSMS" => await SendViaBrandSMS(formattedPhone, message),
                "TWILIO" => await SendViaTwilio(formattedPhone, message),
                _ => await SendViaESMS(formattedPhone, message) // Mặc định
            };

            if (result)
            {
                _logger.LogInformation("✅ Đã gửi SMS thành công đến {PhoneNumber}", phoneNumber);
            }
            else
            {
                _logger.LogError("❌ Không thể gửi SMS đến {PhoneNumber}", phoneNumber);
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi gửi SMS đến {PhoneNumber}", phoneNumber);
            return false;
        }
    }

    /// <summary>
    /// Gửi SMS qua ESMS (https://esms.vn)
    /// </summary>
    private async Task<bool> SendViaESMS(string phoneNumber, string message)
    {
        try
        {
            var apiKey = _configuration["Sms:ESMS:ApiKey"];
            var apiSecret = _configuration["Sms:ESMS:ApiSecret"];
            // Thử để Brandname rỗng nếu chưa đăng ký
            var brandName = _configuration["Sms:ESMS:BrandName"] ?? "";
            // Nếu Brandname là "ICITIZEN" hoặc giá trị mặc định, để rỗng
            if (string.IsNullOrWhiteSpace(brandName) || brandName == "ICITIZEN")
            {
                brandName = "";
            }

            _logger.LogInformation("🔑 ESMS Config - ApiKey: {ApiKey} (length: {Length}), ApiSecret: {ApiSecret} (length: {SecretLength}), BrandName: {BrandName}", 
                string.IsNullOrEmpty(apiKey) ? "NULL" : $"{apiKey.Substring(0, Math.Min(5, apiKey.Length))}...", 
                apiKey?.Length ?? 0,
                string.IsNullOrEmpty(apiSecret) ? "NULL" : $"{apiSecret.Substring(0, Math.Min(5, apiSecret.Length))}...",
                apiSecret?.Length ?? 0,
                brandName);

            if (string.IsNullOrEmpty(apiKey) || string.IsNullOrEmpty(apiSecret))
            {
                _logger.LogError("❌ ESMS API Key hoặc Secret chưa được cấu hình. Kiểm tra appsettings.json");
                return false;
            }

            // Format số điện thoại: ESMS yêu cầu format 0xxxxxxxxx (không có +84)
            var formattedPhone = FormatPhoneForESMS(phoneNumber);
            _logger.LogInformation("📱 Gửi SMS ESMS đến: {FormattedPhone} (từ {OriginalPhone})", formattedPhone, phoneNumber);

            // ESMS API endpoint (thêm dấu / ở cuối để tránh redirect)
            var apiUrl = "https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/";

            var request = new
            {
                ApiKey = apiKey,
                ApiSecret = apiSecret,
                Phone = formattedPhone,
                Content = message,
                Brandname = brandName,
                SmsType = 2 // 2 = CSKH (Chăm sóc khách hàng)
            };

            var json = JsonSerializer.Serialize(request);
            _logger.LogDebug("ESMS Request: {Request}", json);
            
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(apiUrl, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            _logger.LogInformation("ESMS Response: {StatusCode} - {Content}", response.StatusCode, responseContent);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("ESMS API trả về lỗi HTTP: {StatusCode} - {Content}", response.StatusCode, responseContent);
                return false;
            }

            // Parse response
            JsonElement result;
            try
            {
                result = JsonSerializer.Deserialize<JsonElement>(responseContent);
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Không thể parse response từ ESMS: {Content}", responseContent);
                return false;
            }

            if (!result.TryGetProperty("CodeResult", out var codeResultProp))
            {
                _logger.LogError("ESMS response không có CodeResult: {Content}", responseContent);
                return false;
            }

            var codeResult = codeResultProp.GetString();

            // CodeResult = "100" là thành công
            if (codeResult == "100")
            {
                var smsId = result.TryGetProperty("SMSID", out var smsIdProp) ? smsIdProp.GetString() : "N/A";
                _logger.LogInformation("✅ ESMS: Gửi SMS thành công. SMSID: {SmsId}", smsId);
                return true;
            }
            else
            {
                var errorMsg = result.TryGetProperty("ErrorMessage", out var errorMsgProp) 
                    ? errorMsgProp.GetString() 
                    : "Unknown error";
                _logger.LogError("❌ ESMS: Lỗi {CodeResult} - {ErrorMessage}", codeResult, errorMsg);
                
                // Log chi tiết các lỗi thường gặp
                if (codeResult == "101")
                {
                    _logger.LogError("⚠️ API Key hoặc Secret không đúng. Vui lòng kiểm tra lại trong appsettings.json");
                }
                else if (codeResult == "102")
                {
                    _logger.LogError("⚠️ Tài khoản ESMS hết tiền. Vui lòng nạp thêm tiền.");
                }
                else if (codeResult == "103")
                {
                    _logger.LogError("⚠️ Brandname '{BrandName}' chưa được đăng ký. Thử để trống hoặc đăng ký brandname.", brandName);
                }
                
                return false;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Lỗi khi gọi ESMS API: {Message}", ex.Message);
            return false;
        }
    }

    /// <summary>
    /// Format số điện thoại cho ESMS (yêu cầu format 0xxxxxxxxx)
    /// </summary>
    private string FormatPhoneForESMS(string phoneNumber)
    {
        // Loại bỏ khoảng trắng và ký tự đặc biệt
        var cleaned = phoneNumber.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "");

        // Nếu bắt đầu bằng +84, chuyển thành 0
        if (cleaned.StartsWith("+84"))
        {
            return "0" + cleaned.Substring(3);
        }

        // Nếu bắt đầu bằng 84 (không có +), chuyển thành 0
        if (cleaned.StartsWith("84") && cleaned.Length > 2)
        {
            return "0" + cleaned.Substring(2);
        }

        // Nếu đã bắt đầu bằng 0, giữ nguyên
        if (cleaned.StartsWith("0"))
        {
            return cleaned;
        }

        // Mặc định thêm 0 ở đầu
        return "0" + cleaned;
    }

    /// <summary>
    /// Gửi SMS qua BrandSMS (https://brandsms.vn)
    /// </summary>
    private async Task<bool> SendViaBrandSMS(string phoneNumber, string message)
    {
        try
        {
            var apiKey = _configuration["Sms:BrandSMS:ApiKey"];
            var apiUrl = _configuration["Sms:BrandSMS:ApiUrl"] ?? "https://api.brandsms.vn/api/send";

            if (string.IsNullOrEmpty(apiKey))
            {
                _logger.LogError("BrandSMS API Key chưa được cấu hình");
                return false;
            }

            var request = new
            {
                api_key = apiKey,
                phone = phoneNumber,
                message = message
            };

            var json = JsonSerializer.Serialize(request);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            _httpClient.DefaultRequestHeaders.Clear();
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");

            var response = await _httpClient.PostAsync(apiUrl, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("BrandSMS API trả về lỗi: {StatusCode} - {Content}", response.StatusCode, responseContent);
                return false;
            }

            var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
            var success = result.TryGetProperty("success", out var successProp) && successProp.GetBoolean();

            return success;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi gọi BrandSMS API");
            return false;
        }
    }

    /// <summary>
    /// Gửi SMS qua Twilio (cần cài package Twilio)
    /// </summary>
    private async Task<bool> SendViaTwilio(string phoneNumber, string message)
    {
        try
        {
            var accountSid = _configuration["Sms:Twilio:AccountSid"];
            var authToken = _configuration["Sms:Twilio:AuthToken"];
            var fromNumber = _configuration["Sms:Twilio:FromNumber"];

            if (string.IsNullOrEmpty(accountSid) || string.IsNullOrEmpty(authToken) || string.IsNullOrEmpty(fromNumber))
            {
                _logger.LogError("Twilio credentials chưa được cấu hình đầy đủ");
                return false;
            }

            // Cần cài package: dotnet add package Twilio
            // Uncomment code sau khi đã cài package:
            /*
            TwilioClient.Init(accountSid, authToken);
            var result = await MessageResource.CreateAsync(
                body: message,
                from: new PhoneNumber(fromNumber),
                to: new PhoneNumber(phoneNumber)
            );
            return result.Status != MessageResource.StatusEnum.Failed;
            */

            _logger.LogWarning("Twilio chưa được tích hợp. Cần cài package: dotnet add package Twilio");
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi gọi Twilio API");
            return false;
        }
    }

    /// <summary>
    /// Format số điện thoại Việt Nam
    /// </summary>
    private string FormatPhoneNumber(string phoneNumber)
    {
        // Loại bỏ khoảng trắng và ký tự đặc biệt
        var cleaned = phoneNumber.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "");

        // Nếu bắt đầu bằng 0, chuyển thành +84
        if (cleaned.StartsWith("0"))
        {
            return "+84" + cleaned.Substring(1);
        }

        // Nếu chưa có +84, thêm vào
        if (!cleaned.StartsWith("+84"))
        {
            return "+84" + cleaned;
        }

        return cleaned;
    }
}
