using PTVBTPM.Models;
using PTVBTPM.Services;
using PTVBTPM.Models.Configurations;
using PTVBTPM.Models.Entities;
using PTVBTPM.Hubs;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using DotNetEnv;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.OpenApi.Models;

// Load .env file
Env.Load();

var builder = WebApplication.CreateBuilder(args);

// Replace placeholders in configuration with environment variables
// Format: ${VAR_NAME} will be replaced with value from .env file
ReplaceConfigPlaceholders(builder.Configuration);

// Helper method to replace ${VAR_NAME} placeholders in configuration
void ReplaceConfigPlaceholders(IConfiguration configuration)
{
    // Get all configuration keys
    var configKeys = new List<string>();
    foreach (var item in configuration.AsEnumerable())
    {
        if (!string.IsNullOrEmpty(item.Key))
        {
            configKeys.Add(item.Key);
        }
    }

    // Replace placeholders in each configuration value
    foreach (var key in configKeys)
    {
        var value = configuration[key];
        if (!string.IsNullOrEmpty(value) && value.Contains("${"))
        {
            // Replace ${VAR_NAME} with environment variable value
            var replacedValue = Regex.Replace(
                value,
                @"\$\{([^}]+)\}",
                match =>
                {
                    var envVarName = match.Groups[1].Value;
                    var envValue = Environment.GetEnvironmentVariable(envVarName);
                    return envValue ?? match.Value; // Keep original if env var not found
                }
            );

            // Handle special cases for numeric/boolean values
            if (replacedValue != value)
            {
                // Try to parse as int
                if (int.TryParse(replacedValue, out var intValue))
                {
                    builder.Configuration[key] = intValue.ToString();
                }
                // Try to parse as bool
                else if (bool.TryParse(replacedValue, out var boolValue))
                {
                    builder.Configuration[key] = boolValue.ToString().ToLower();
                }
                // Try to parse as decimal
                else if (decimal.TryParse(replacedValue, out var decimalValue))
                {
                    builder.Configuration[key] = decimalValue.ToString();
                }
                else
                {
                    builder.Configuration[key] = replacedValue;
                }
            }
        }
    }
}

// Add services to the container.
builder.Services.AddHttpContextAccessor();
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
        options.JsonSerializerOptions.WriteIndented = true; // Format JSON đẹp (indented)
    });

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "PTVBTPM API",
        Version = "v1",
        Description = "API documentation for PTVBTPM - Printing System"
    });
    
    // Include XML comments if available
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
    
    // Handle nullable reference types
    c.SupportNonNullableReferenceTypes();
    
    // Use fully qualified names to avoid conflicts
    c.CustomSchemaIds(type => type.FullName);
    
    // Ignore obsolete properties
    c.IgnoreObsoleteProperties();
    
    // Ignore obsolete actions
    c.IgnoreObsoleteActions();
    
    // Resolve conflicts for same schema names
    c.ResolveConflictingActions(apiDescriptions => apiDescriptions.First());
    
    // Ignore controllers that might cause issues
    c.DocInclusionPredicate((docName, apiDesc) =>
    {
        // Include all APIs
        return true;
    });
    
    // Support file upload parameters (IFormFile) in Swagger
    c.OperationFilter<PTVBTPM.Swagger.FileUploadOperationFilter>();

    // Add operation filter to fix Register endpoint issue
    c.OperationFilter<PTVBTPM.Swagger.RegisterEndpointFilter>();
});

// Configure Database
builder.Services.AddDbContext<WebDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Configure Settings
builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.Configure<SepayConfig>(builder.Configuration.GetSection("SepayConfig"));
builder.Services.Configure<HooksConfig>(builder.Configuration.GetSection("HooksConfig"));

// Configure Services
builder.Services.AddSingleton<IEmailService, EmailService>();
builder.Services.AddScoped<IHooksService, HooksService>();
builder.Services.AddScoped<ITwoFactorAuthService, TwoFactorAuthService>();
builder.Services.AddScoped<HooksService>();
builder.Services.AddScoped<ReportService>();

// Add Background Service for Print Job Processing
builder.Services.AddHostedService<PrintJobProcessingService>();

// Add Background Service for Auto Assign Pages
builder.Services.AddHostedService<AutoAssignPagesService>();

// Add Background Service for Report Generation
builder.Services.AddHostedService<ReportBackgroundService>();

// Add Memory Cache
builder.Services.AddMemoryCache();

// Add Distributed Memory Cache for Session (required by Session middleware)
builder.Services.AddDistributedMemoryCache();

// Add Session
// Note: Session timeout sẽ được check bởi SessionTimeoutMiddleware dựa trên system config
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromHours(24); // Set max timeout, middleware sẽ check theo config
    options.Cookie.HttpOnly = true; // Cookie chỉ accessible qua HTTP, không qua JavaScript
    options.Cookie.IsEssential = true; // Cookie essential cho app hoạt động
    options.Cookie.SameSite = SameSiteMode.Lax; // CSRF protection
});

// Add SignalR for real-time notifications
builder.Services.AddSignalR(options =>
{
    // Configure SignalR options for better performance and reliability
    options.EnableDetailedErrors = true; // Enable detailed errors in development
    options.MaximumReceiveMessageSize = 1024 * 1024; // 1MB max message size
    options.StreamBufferCapacity = 10; // Buffer capacity for streaming
    options.KeepAliveInterval = TimeSpan.FromSeconds(15); // Send keep-alive every 15 seconds
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(30); // Client timeout after 30 seconds
    options.HandshakeTimeout = TimeSpan.FromSeconds(15); // Handshake timeout
});

// Configure Authentication
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = "Session";
    options.DefaultChallengeScheme = "Session";
})
.AddCookie("Session", options =>
{
    options.Cookie.Name = ".AspNetCore.Session";
    options.Cookie.HttpOnly = true;
    // Remove login path to prevent redirect to non-existent route
    options.AccessDeniedPath = "/api/auth/access-denied"; // Optional: redirect path for forbidden requests
});

// Add CORS to allow webhook and SignalR connections
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowSePayWebhook", policy =>
    {
        policy
            .WithOrigins(
                "http://34.9.120.106:5000",
                "http://34.9.120.106",
                "https://doantrang.online",
                "http://localhost:5273",
                "http://localhost:5174",
                "http://localhost:5173"
            )
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials(); // Required for SignalR and Session cookies
    });
});


var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseRouting();

// Enable static files from wwwroot
// Note: Temp files are now stored in system temp folder, not in wwwroot, so no need to block
app.UseStaticFiles();

// Add middleware to handle /v1/swagger.json requests BEFORE Swagger middleware
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/v1/swagger.json"))
    {
        context.Request.Path = "/swagger/v1/swagger.json";
    }
    await next();
});

// Configure Swagger to handle both /swagger/v1/swagger.json and /v1/swagger.json
app.UseSwagger(c =>
{
    c.RouteTemplate = "swagger/{documentName}/swagger.json";
});

app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "PTVBTPM - API V1");
    c.RoutePrefix = "swagger"; // Swagger UI will be available at /swagger
});

// Enable CORS (must be before UseAuthorization)
app.UseCors("AllowSePayWebhook");

// Use Authentication (must be before UseAuthorization)
app.UseAuthentication();

// Use Session (must be after UseRouting and before UseAuthorization)
app.UseSession();

// Use Session Timeout Middleware (check timeout based on system config)
app.UseMiddleware<PTVBTPM.Middleware.SessionTimeoutMiddleware>();

app.UseWebSockets();

app.UseAuthorization();

// Map SignalR Hubs
app.MapHub<PaymentHub>("/paymentHub");
app.MapHub<PrintHub>("/printHub");
app.MapHub<PresenceHub>("/presenceHub");

app.MapControllers();

app.Run();

