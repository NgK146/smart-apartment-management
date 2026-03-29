using Microsoft.Extensions.Configuration;
using Twilio;
using Twilio.Rest.Api.V2010.Account;
using Twilio.Types;

namespace ICitizen.Services;

public class TwilioSmsSender : ISmsSender
{
    private readonly IConfiguration _config;
    private string? _fromNumber;
    private bool _isInitialized = false;

    public TwilioSmsSender(IConfiguration config)
    {
        _config = config;
    }

    private void EnsureInitialized()
    {
        if (_isInitialized) return;

        var accountSid = _config["Sms:Twilio:AccountSid"];
        var authToken  = _config["Sms:Twilio:AuthToken"];
        _fromNumber    = _config["Sms:Twilio:FromNumber"] ?? "";

        if (string.IsNullOrWhiteSpace(accountSid) ||
            string.IsNullOrWhiteSpace(authToken) ||
            string.IsNullOrWhiteSpace(_fromNumber))
        {
            throw new Exception("Twilio configuration is missing. Please configure Sms:Twilio:AccountSid, Sms:Twilio:AuthToken, and Sms:Twilio:FromNumber in appsettings.json");
        }

        TwilioClient.Init(accountSid, authToken);
        _isInitialized = true;
    }

    /// <summary>
    /// Chuyển đổi số điện thoại Việt Nam sang định dạng E.164 (+84...)
    /// </summary>
    private string FormatPhoneToE164(string phoneNumber)
    {
        // Loại bỏ khoảng trắng và ký tự đặc biệt
        var cleaned = phoneNumber.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "").Trim();

        // Nếu đã có +84, giữ nguyên
        if (cleaned.StartsWith("+84"))
        {
            return cleaned;
        }

        // Nếu bắt đầu bằng 84 (không có +), thêm +
        if (cleaned.StartsWith("84") && cleaned.Length >= 10)
        {
            return "+" + cleaned;
        }

        // Nếu bắt đầu bằng 0, chuyển thành +84
        if (cleaned.StartsWith("0") && cleaned.Length >= 10)
        {
            return "+84" + cleaned.Substring(1);
        }

        // Nếu không có prefix, thêm +84
        if (cleaned.Length >= 9)
        {
            return "+84" + cleaned;
        }

        // Nếu không thể format, trả về nguyên bản (sẽ để Twilio báo lỗi)
        return phoneNumber;
    }

    public async Task SendAsync(string phoneNumber, string message)
    {
        EnsureInitialized();
        
        // Chuyển đổi số điện thoại sang định dạng E.164 (+84xxxxxxxxx)
        var formattedPhone = FormatPhoneToE164(phoneNumber);
        
        var msg = await MessageResource.CreateAsync(
            to:   new PhoneNumber(formattedPhone),
            from: new PhoneNumber(_fromNumber!),
            body: message
        );

        if (msg.ErrorCode != null)
        {
            throw new Exception($"Twilio send failed: {msg.ErrorCode} - {msg.ErrorMessage}");
        }
    }
}


