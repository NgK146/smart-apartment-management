using System.Security.Cryptography;
using System.Text;

namespace ICitizen.Common
{
    /// <summary>
    /// Helper class để generate và validate QR codes
    /// </summary>
    public static class QRCodeHelper
    {
        /// <summary>
        /// Generate QR code cho Visitor Access
        /// Format: VISITOR_{timestamp}_{hash}
        /// </summary>
        public static string GenerateVisitorQRCode()
        {
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var randomBytes = new byte[8];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(randomBytes);
            }
            var hash = Convert.ToBase64String(randomBytes)
                .Replace("+", "-")
                .Replace("/", "_")
                .Substring(0, 12);
            return $"VISITOR_{timestamp}_{hash}";
        }

        /// <summary>
        /// Generate QR code cho Event Check-in
        /// Format: EVENT_{eventId}_{registrationId}_{hash}
        /// </summary>
        public static string GenerateEventCheckInQRCode(Guid eventId, Guid registrationId)
        {
            var hash = GenerateShortHash($"{eventId}_{registrationId}");
            return $"EVENT_{eventId:N}_{registrationId:N}_{hash}";
        }

        /// <summary>
        /// Generate QR code cho Barrier Access
        /// Format: BARRIER_{barrierId}_{userId}_{timestamp}_{hash}
        /// </summary>
        public static string GenerateBarrierQRCode(Guid barrierId, Guid userId)
        {
            var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var hash = GenerateShortHash($"{barrierId}_{userId}_{timestamp}");
            return $"BARRIER_{barrierId:N}_{userId:N}_{timestamp}_{hash}";
        }

        /// <summary>
        /// Generate OTP cho Smart Locker
        /// Format: 6-digit number
        /// </summary>
        public static string GenerateLockerOTP()
        {
            var random = new Random();
            return random.Next(100000, 999999).ToString();
        }

        /// <summary>
        /// Validate QR code format
        /// </summary>
        public static bool IsValidQRCodeFormat(string qrCode, QRCodeType type)
        {
            if (string.IsNullOrWhiteSpace(qrCode))
                return false;

            return type switch
            {
                QRCodeType.Visitor => qrCode.StartsWith("VISITOR_") && qrCode.Split('_').Length == 3,
                QRCodeType.Event => qrCode.StartsWith("EVENT_") && qrCode.Split('_').Length >= 3,
                QRCodeType.Barrier => qrCode.StartsWith("BARRIER_") && qrCode.Split('_').Length >= 4,
                _ => false
            };
        }

        /// <summary>
        /// Parse visitor QR code để lấy timestamp
        /// </summary>
        public static DateTime? ParseVisitorQRCodeTimestamp(string qrCode)
        {
            if (!IsValidQRCodeFormat(qrCode, QRCodeType.Visitor))
                return null;

            var parts = qrCode.Split('_');
            if (parts.Length < 2 || !long.TryParse(parts[1], out var timestamp))
                return null;

            return DateTimeOffset.FromUnixTimeSeconds(timestamp).DateTime;
        }

        private static string GenerateShortHash(string input)
        {
            using var sha256 = SHA256.Create();
            var hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input));
            return Convert.ToBase64String(hashBytes)
                .Replace("+", "-")
                .Replace("/", "_")
                .Substring(0, 12);
        }
    }

    public enum QRCodeType
    {
        Visitor,
        Event,
        Barrier,
        Locker
    }
}



