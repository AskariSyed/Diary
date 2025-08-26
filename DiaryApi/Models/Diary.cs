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
        public Note Note { get; set; }
        public ICollection<Page> Pages { get; set; } = new List<Page>();
    }
}

