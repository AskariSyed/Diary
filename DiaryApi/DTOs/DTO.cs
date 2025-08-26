using System;
using System.ComponentModel.DataAnnotations;

namespace DiaryApi.Dtos
{
    public class CreateTaskDto
    {
        [Required]
        public int PageId { get; set; }

        [Required]
        [StringLength(255)]
        public string Title { get; set; }

        [Required]
        [StringLength(50)]
        public string Status { get; set; }
    }

    public class UpdateTaskStatusDto
    {
        [Required]
        [StringLength(50)]
        public string Status { get; set; }
    }

    public class UpdateTaskTitleDto
    {
        [Required]
        [StringLength(255)]
        public string Title { get; set; }
    }

    public class CreatePageDto
    {
        [Required]
        public DateTime PageDate { get; set; }

        [Required]
        public int DiaryNo { get; set; }
    }
    public class DiaryDto
    {
        public int Id { get; set; }
        public DateTime CreatedDate { get; set; }

        [Required(ErrorMessage = "Owner name is required.")]
        [StringLength(100, ErrorMessage = "Owner name cannot exceed 100 characters.")]
        public string OwnerName { get; set; }

    }

    public class DiaryCreateDto
    {
        [Required(ErrorMessage = "Owner name is required.")]
        [StringLength(100, ErrorMessage = "Owner name cannot exceed 100 characters.")]
        public string OwnerName { get; set; }
    }

    public class PageTaskResponseDto
    {
        public int Id { get; set; }
        public int PageId { get; set; }
        public int ParentTaskId { get; set; }
        public string Status { get; set; }
        public string Title { get; set; }
        public DateTime PageDate { get; set; }

        public DateTime ParentTaskCreatedAt { get; set; }
    }

    public class TaskHistoryDto
    {
        public int PageTaskId { get; set; }
        public int PageId { get; set; }
        public DateTime PageDate { get; set; }
        public string Title { get; set; }
        public string Status { get; set; }
        public DateTime ParentTaskCreatedAt { get; set; }
    }
  
public class CopyTasksDto
    {
        [Required(ErrorMessage = "Source page date is required.")]
        public DateTime SourcePageDate { get; set; }

        [Required(ErrorMessage = "Target page date is required.")]
        public DateTime TargetPageDate { get; set; }
    }


    public class NoteUpdateDto
    {
        public string Description { get; set; }
    }
    public class NoteDto
    {
        public int Id { get; set; }
        public string Description { get; set; }
    }
}

