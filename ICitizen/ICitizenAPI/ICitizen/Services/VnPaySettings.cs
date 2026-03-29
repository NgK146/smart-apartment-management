namespace ICitizen.Services;

public class VnPaySettings
{
    public string TmnCode { get; set; } = string.Empty;
    public string HashSecret { get; set; } = string.Empty;
    public string BaseUrl { get; set; } = string.Empty;
    public string ReturnUrl { get; set; } = string.Empty;
    public string IpnUrl { get; set; } = string.Empty;
    public string Locale { get; set; } = "vn";
    public string OrderType { get; set; } = "other";
    public string Currency { get; set; } = "VND";
    public int PaymentTimeoutMinutes { get; set; } = 15;
}

