using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ICitizen.Services;

public class EmailSender : IEmailSender
{
    private readonly IConfiguration _config;
    private readonly ILogger<EmailSender> _logger;

    public EmailSender(IConfiguration config, ILogger<EmailSender> logger)
    {
        _config = config;
        _logger = logger;
    }

    public async Task SendEmailAsync(string email, string subject, string message)
    {
        var smtpHost = _config["Email:SmtpHost"];
        var smtpPortStr = _config["Email:SmtpPort"];
        var smtpUser = _config["Email:SmtpUser"];
        var smtpPass = _config["Email:SmtpPass"];

        if (string.IsNullOrWhiteSpace(smtpHost) ||
            string.IsNullOrWhiteSpace(smtpPortStr) ||
            string.IsNullOrWhiteSpace(smtpUser) ||
            string.IsNullOrWhiteSpace(smtpPass))
        {
            _logger.LogError("SMTP config is missing. Please check Email:SmtpHost/Port/User/Pass in appsettings.");
            throw new InvalidOperationException("SMTP config is missing.");
        }

        var smtpPort = int.Parse(smtpPortStr);

        using var client = new SmtpClient(smtpHost, smtpPort)
        {
            Credentials = new NetworkCredential(smtpUser, smtpPass),
            EnableSsl = true
        };

        using var mail = new MailMessage(smtpUser, email, subject, message)
        {
            IsBodyHtml = true
        };

        await client.SendMailAsync(mail);
    }
}

