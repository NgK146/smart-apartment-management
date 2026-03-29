using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace ICitizen.Services;

public interface IVnPayService
{
    string CreatePaymentUrl(Guid paymentId, decimal amount, string orderInfo, HttpContext httpContext);
    bool ValidateSignature(IQueryCollection query);
    IDictionary<string, string> GetVnPayData(IQueryCollection query);
}

public class VnPayService : IVnPayService
{
    private readonly VnPaySettings _settings;

    public VnPayService(IOptions<VnPaySettings> options)
    {
        _settings = options.Value;
    }

    public string CreatePaymentUrl(Guid paymentId, decimal amount, string orderInfo, HttpContext context)
    {
        long price = (long)(amount * 100); // VNPay yêu cầu *100
        var ipAddress = ResolveClientIp(context);
        var now = DateTime.UtcNow;
        var expireMinutes = Math.Max(0, _settings.PaymentTimeoutMinutes);
        var orderDescription = NormalizeOrderInfo(orderInfo);
        var currency = string.IsNullOrWhiteSpace(_settings.Currency) ? "VND" : _settings.Currency;
        var locale = string.IsNullOrWhiteSpace(_settings.Locale) ? "vn" : _settings.Locale;
        var orderType = string.IsNullOrWhiteSpace(_settings.OrderType) ? "other" : _settings.OrderType;

        var vnpParams = new SortedDictionary<string, string>
        {
            ["vnp_Version"] = "2.1.0",
            ["vnp_Command"] = "pay",
            ["vnp_TmnCode"] = _settings.TmnCode,
            ["vnp_Amount"] = price.ToString(),
            ["vnp_CreateDate"] = now.ToString("yyyyMMddHHmmss"),
            ["vnp_CurrCode"] = currency,
            ["vnp_IpAddr"] = ipAddress,
            ["vnp_Locale"] = locale,
            ["vnp_OrderInfo"] = orderDescription,
            ["vnp_OrderType"] = orderType,
            ["vnp_ReturnUrl"] = _settings.ReturnUrl,
            ["vnp_TxnRef"] = paymentId.ToString("N") // mã giao dịch: dùng luôn paymentId dạng N
        };

        if (!string.IsNullOrWhiteSpace(_settings.IpnUrl))
        {
            vnpParams["vnp_IpnUrl"] = _settings.IpnUrl;
        }

        if (expireMinutes > 0)
        {
            var expireDate = now.AddMinutes(expireMinutes);
            vnpParams["vnp_ExpireDate"] = expireDate.ToString("yyyyMMddHHmmss");
        }

        var query = BuildQuery(vnpParams);
        var rawData = query.TrimEnd('&');

        var secureHash = HmacSHA512(_settings.HashSecret, rawData);
        var paymentUrl = $"{_settings.BaseUrl}?{rawData}&vnp_SecureHash={secureHash}";

        return paymentUrl;
    }

    public bool ValidateSignature(IQueryCollection query)
    {
        var hashSecret = _settings.HashSecret;
        var vnpSecureHash = query["vnp_SecureHash"].ToString();
        if (string.IsNullOrEmpty(vnpSecureHash)) return false;

        var data = new SortedDictionary<string, string>();
        foreach (var key in query.Keys)
        {
            if (key.StartsWith("vnp_") &&
                key != "vnp_SecureHash" &&
                key != "vnp_SecureHashType")
            {
                data[key] = query[key]!;
            }
        }

        var rawData = BuildQuery(data).TrimEnd('&');
        var checkHash = HmacSHA512(hashSecret, rawData);

        return string.Equals(checkHash, vnpSecureHash, StringComparison.OrdinalIgnoreCase);
    }

    public IDictionary<string, string> GetVnPayData(IQueryCollection query)
    {
        var dict = new Dictionary<string, string>();
        foreach (var key in query.Keys)
        {
            if (key.StartsWith("vnp_"))
                dict[key] = query[key]!;
        }
        return dict;
    }

    private static string BuildQuery(SortedDictionary<string, string> data)
    {
        var query = new StringBuilder();
        foreach (var kv in data)
        {
            if (!string.IsNullOrEmpty(kv.Value))
            {
                query.Append(Uri.EscapeDataString(kv.Key));
                query.Append('=');
                query.Append(Uri.EscapeDataString(kv.Value));
                query.Append('&');
            }
        }
        return query.ToString();
    }

    private static string ResolveClientIp(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue("X-Forwarded-For", out var forwarded))
        {
            var first = forwarded.ToString().Split(',', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(first))
                return first.Trim();
        }

        return context.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1";
    }

    private static string NormalizeOrderInfo(string info)
    {
        if (string.IsNullOrWhiteSpace(info))
            return "Thanh toan hoa don";

        var trimmed = info.Trim();
        if (trimmed.Length > 255)
            trimmed = trimmed[..255];

        return trimmed;
    }

    private static string HmacSHA512(string key, string inputData)
    {
        var keyBytes = Encoding.UTF8.GetBytes(key);
        var inputBytes = Encoding.UTF8.GetBytes(inputData);
        using var hmac = new HMACSHA512(keyBytes);
        var hashValue = hmac.ComputeHash(inputBytes);
        return string.Concat(hashValue.Select(b => b.ToString("x2")));
    }
}
