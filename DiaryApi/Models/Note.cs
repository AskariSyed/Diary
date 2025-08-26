namespace DiaryApi.Models
{
    public class Note
    {
        public int Id { get; set; }
       
        public string Description { get; set; }
        
        public int DiaryId { get; set; }
        
        public Diary Diary { get; set; }
    }
}
