using System.Linq;
using Microsoft.AspNetCore.Http;
using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace PTVBTPM.Swagger;

/// <summary>
/// Operation filter to let Swashbuckle generate multipart/form-data for actions that accept IFormFile and mixed form data
/// </summary>
public class FileUploadOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        // Only apply to the UpdateProfile endpoint which actually needs file upload handling
        var actionName = context.MethodInfo.Name;
        var controllerName = context.MethodInfo.DeclaringType?.Name;

        if (actionName != "UpdateProfile" || controllerName != "AuthenticationController")
            return;

        // Verify this endpoint actually has IFormFile parameters
        var allParameters = context.MethodInfo.GetParameters();
        var fileParameters = allParameters
            .Where(p => p.ParameterType == typeof(IFormFile) || p.ParameterType == typeof(IFormFileCollection));

        if (!fileParameters.Any())
            return;

        // Check if action has [Consumes("multipart/form-data")] attribute
        var consumesMultipart = context.MethodInfo.GetCustomAttributes(typeof(Microsoft.AspNetCore.Mvc.ConsumesAttribute), false)
            .Cast<Microsoft.AspNetCore.Mvc.ConsumesAttribute>()
            .Any(attr => attr.ContentTypes.Contains("multipart/form-data"));

        if (!consumesMultipart && !fileParameters.Any()) return;

        // Ensure requestBody exists
        operation.RequestBody = operation.RequestBody ?? new OpenApiRequestBody();

        operation.RequestBody.Content.Clear();

        var schema = new OpenApiSchema
        {
            Type = "object",
            Properties = new Dictionary<string, OpenApiSchema>()
        };

        // Add file parameters (only IFormFile for UpdateProfile)
        foreach (var param in fileParameters)
        {
            if (param.ParameterType == typeof(IFormFileCollection))
            {
                schema.Properties[param.Name!] = new OpenApiSchema
                {
                    Type = "array",
                    Items = new OpenApiSchema { Type = "string", Format = "binary" }
                };
            }
            else
            {
                schema.Properties[param.Name!] = new OpenApiSchema { Type = "string", Format = "binary" };
            }
        }

        // For UpdateProfile, also handle the other form fields from UpdateProfileRequestDto
        var allParams = context.MethodInfo.GetParameters();
        foreach (var param in allParams)
        {
            if (!schema.Properties.ContainsKey(param.Name!))
            {
                var paramType = param.ParameterType;

                // Handle nullable types
                if (Nullable.GetUnderlyingType(paramType) != null)
                {
                    paramType = Nullable.GetUnderlyingType(paramType)!;
                }

                OpenApiSchema paramSchema;
                if (paramType == typeof(string))
                {
                    paramSchema = new OpenApiSchema { Type = "string" };
                }
                else if (paramType == typeof(int) || paramType == typeof(long))
                {
                    paramSchema = new OpenApiSchema { Type = "integer", Format = paramType == typeof(long) ? "int64" : "int32" };
                }
                else if (paramType == typeof(bool))
                {
                    paramSchema = new OpenApiSchema { Type = "boolean" };
                }
                else if (paramType == typeof(DateTime))
                {
                    paramSchema = new OpenApiSchema { Type = "string", Format = "date-time" };
                }
                else
                {
                    // Default to string for unknown types
                    paramSchema = new OpenApiSchema { Type = "string" };
                }

                schema.Properties[param.Name!] = paramSchema;
            }
        }

        operation.RequestBody.Content.Add("multipart/form-data", new OpenApiMediaType
        {
            Schema = schema
        });

        // Mark required parameters
        var requiredParams = allParameters
            .Where(p => !p.HasDefaultValue &&
                       !(p.ParameterType.IsGenericType && p.ParameterType.GetGenericTypeDefinition() == typeof(Nullable<>)))
            .Select(p => p.Name!)
            .ToHashSet();

        if (requiredParams.Any())
        {
            operation.RequestBody.Required = true;
            schema.Required = requiredParams;
        }
    }
}


