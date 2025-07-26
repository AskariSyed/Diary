namespace DiaryApi.Models
{
    // This is the join entity between Page and Task
    public class PageTask
    {
        public int Id { get; set; }
        public int PageId { get; set; }
        public int ParentTaskId { get; set; }
        public string Status { get; set; }
        public string Title { get; set; }

        public Page Page { get; set; }
        public DiaryTask ParentTask { get; set; }
    }
}
