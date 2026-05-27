using System;

namespace PTVBTPM.Helper;

/// <summary>
/// Helper class for building URLs with domain from environment variable
/// </summary>
public static class UrlHelper
{
    /// <summary>
    /// Get the application domain from environment variable APP_DOMAIN
    /// Defaults to https://doantrang.online if not set
    /// </summary>
    public static string GetAppDomain()
    {
        var domain = Environment.GetEnvironmentVariable("APP_DOMAIN");
        if (string.IsNullOrWhiteSpace(domain))
        {
            // Default domain if not set
            return "https://doantrang.online";
        }
        return domain.TrimEnd('/'); // Remove trailing slash if present
    }

    /// <summary>
    /// Build a full URL for an uploaded file
    /// Example: GetFileUrl("Uploads/image.jpg") returns "https://doantrang.online/Uploads/image.jpg"
    /// </summary>
    /// <param name="relativePath">Relative path from wwwroot (e.g., "Uploads/image.jpg")</param>
    /// <returns>Full URL to the file</returns>
    public static string GetFileUrl(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath))
            return string.Empty;

        var domain = GetAppDomain();
        var cleanPath = relativePath.TrimStart('/'); // Remove leading slash if present
        
        return $"{domain}/{cleanPath}";
    }

    /// <summary>
    /// Build a full URL for an uploaded image in the Uploads folder
    /// Example: GetUploadUrl("image.jpg") returns "https://doantrang.online/Uploads/image.jpg"
    /// </summary>
    /// <param name="fileName">File name (e.g., "image.jpg")</param>
    /// <returns>Full URL to the uploaded file</returns>
    public static string GetUploadUrl(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
            return string.Empty;

        return GetFileUrl($"Uploads/{fileName}");
    }
}

