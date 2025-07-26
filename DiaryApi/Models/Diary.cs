using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace DiaryApi.Models
{
    public class Diary
    {
        public int Id { get; set; }
        public DateTime CreatedDate { get; set; }
        public string OwnerName { get; set; }

        // Navigation property for related pages
        public ICollection<Page> Pages { get; set; } = new List<Page>();
    }
}

