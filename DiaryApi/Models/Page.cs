using Microsoft.AspNetCore.Mvc.RazorPages;
using System;
using System.Collections.Generic;

namespace DiaryApi.Models
{
    public class Page
    {
        public int PageId { get; set; }
        public DateTime PageDate { get; set; }
        public int DiaryNo { get; set; }

        // Navigation property for the parent diary
        public Diary Diary { get; set; }

        // Navigation property for related tasks on this page
        public ICollection<PageTask> PageTasks { get; set; } = new List<PageTask>();
    }
}
