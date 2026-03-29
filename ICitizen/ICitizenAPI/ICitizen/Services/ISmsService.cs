namespace ICitizen.Services;

/// <summary>
/// Interface cho dịch vụ gửi SMS
/// </summary>
public interface ISmsService
{
    /// <summary>
    /// Gửi SMS đến số điện thoại
    /// </summary>
    /// <param name="phoneNumber">Số điện thoại (format: 0901234567 hoặc +84901234567)</param>
    /// <param name="message">Nội dung tin nhắn</param>
    /// <returns>True nếu gửi thành công</returns>
    Task<bool> SendSmsAsync(string phoneNumber, string message);
}

