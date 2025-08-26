using Microsoft.EntityFrameworkCore;
using DiaryApi.Models;

namespace DiaryApi.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<Diary> Diaries { get; set; }
        public DbSet<Page> Pages { get; set; }
        public DbSet<DiaryTask> DiaryTasks { get; set; } // <-- Updated from Tasks
        public DbSet<PageTask> PageTasks { get; set; }
        public DbSet<Note> Notes { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // --- Diary Entity Configuration ---
            modelBuilder.Entity<Diary>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.OwnerName)
                    .IsRequired()
                    .HasMaxLength(100);

                entity.Property(e => e.CreatedDate)
                    .IsRequired()
                    .HasDefaultValueSql("NOW()");
            });

            // --- Page Entity Configuration ---
            modelBuilder.Entity<Page>(entity =>
            {
                entity.HasKey(e => e.PageId);
                entity.Property(e => e.PageId).ValueGeneratedOnAdd();

                entity.Property(e => e.PageDate).HasColumnType("date");

                entity.HasOne(p => p.Diary)
                      .WithMany(d => d.Pages)
                      .HasForeignKey(p => p.DiaryNo)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // --- DiaryTask Entity Configuration (Previously Task) ---
            modelBuilder.Entity<DiaryTask>(entity => // <-- Updated from Task
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.Title)
                    .IsRequired()
                    .HasMaxLength(255);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.CreatedAt)
                    .IsRequired()
                    .HasDefaultValueSql("NOW()");
            });

            // --- PageTask Entity (Join Table) Configuration ---
            modelBuilder.Entity<PageTask>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.Title)
                    .IsRequired()
                    .HasMaxLength(255);

                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.HasOne(pt => pt.Page)
                      .WithMany(p => p.PageTasks)
                      .HasForeignKey(pt => pt.PageId)
                      .OnDelete(DeleteBehavior.Restrict);

                // Updated relationship to point to DiaryTask
                entity.HasOne(pt => pt.ParentTask)
                      .WithMany(t => t.PageTasks)
                      .HasForeignKey(pt => pt.ParentTaskId)
                      .OnDelete(DeleteBehavior.Restrict);
            });
        }
    }
}
