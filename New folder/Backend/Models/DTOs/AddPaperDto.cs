using System.ComponentModel.DataAnnotations;

namespace PTVBTPM.Models.DTOs;

public sealed class AddPaperDto
{
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "Số giấy phải lớn hơn 0")]
    public int PaperCount { get; set; }

    // For backward compatibility with PrinterPaperController
    public int AdditionalPages { get; set; }
}
