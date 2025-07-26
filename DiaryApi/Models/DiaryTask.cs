using Microsoft.AspNetCore.Mvc.RazorPages;
using System;
using System.Collections.Generic;

namespace DiaryApi.Models
{
    public class DiaryTask
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Status { get; set; }
        public DateTime CreatedAt { get; set; }

        // Navigation property for join entities
        public ICollection<PageTask> PageTasks { get; set; } = new List<PageTask>();
    }
}
