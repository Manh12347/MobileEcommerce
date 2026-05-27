using Microsoft.OpenApi.Models;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace PTVBTPM.Swagger;

/// <summary>
/// Operation filter to ensure Register endpoint is treated as JSON, not multipart/form-data
/// </summary>
public class RegisterEndpointFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        // Only apply to Register endpoint
        var actionName = context.MethodInfo.Name;
        var controllerName = context.MethodInfo.DeclaringType?.Name;

        if (actionName == "Register" && controllerName == "AuthenticationController")
        {
            // Ensure this endpoint uses JSON content type
            if (operation.RequestBody != null)
            {
                operation.RequestBody.Content.Clear();
                operation.RequestBody.Content.Add("application/json", new OpenApiMediaType
                {
                    Schema = context.SchemaGenerator.GenerateSchema(
                        context.MethodInfo.GetParameters().First().ParameterType,
                        context.SchemaRepository)
                });
            }
        }
    }
}


