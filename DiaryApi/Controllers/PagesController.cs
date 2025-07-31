using DiaryApi.Data;
using DiaryApi.Dtos;
using DiaryApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Collections.Generic; 
namespace DiaryApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PagesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public PagesController(AppDbContext context)
        {
            _context = context;
        }
        [HttpPost("create")]
        public async Task<IActionResult> CreatePage([FromBody] CreatePageDto createPageDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            var diaryExists = await _context.Diaries.AnyAsync(d => d.Id == createPageDto.DiaryNo);
            if (!diaryExists)
            {
                return NotFound($"Diary with ID {createPageDto.DiaryNo} not found.");
            }
            var targetDate = createPageDto.PageDate.Date;

            var existingPageOnDate = await _context.Pages
                .Where(p => p.DiaryNo == createPageDto.DiaryNo)
                .AnyAsync(p => p.PageDate.Year == targetDate.Year &&
                               p.PageDate.Month == targetDate.Month &&
                               p.PageDate.Day == targetDate.Day);

            if (existingPageOnDate)
            {
                return Conflict($"A page already exists for Diary ID {createPageDto.DiaryNo} on {createPageDto.PageDate.Date:yyyy-MM-dd}.");
            }
            var newPage = new Page
            {
                PageDate = createPageDto.PageDate.Date, 
                   DiaryNo = createPageDto.DiaryNo
            };

            _context.Pages.Add(newPage);
            var lastPageDate = await _context.Pages
                                            .Where(p => p.DiaryNo == createPageDto.DiaryNo && p.PageDate < createPageDto.PageDate.Date)
                                            .Select(p => p.PageDate)
                                            .OrderByDescending(pd => pd)
                                            .FirstOrDefaultAsync();

            if (lastPageDate != default(DateTime)) 
            {
                var pagesFromLastDay = await _context.Pages
                                                    .Where(p => p.DiaryNo == createPageDto.DiaryNo && p.PageDate == lastPageDate)
                                                    .Select(p => p.PageId) 
                                                    .ToListAsync();

                if (pagesFromLastDay.Any())
                {
                    var tasksToCopy = await _context.PageTasks
                                                    .Where(pt => pagesFromLastDay.Contains(pt.PageId) &&
                                                                 pt.Status.ToLower() != "completed" && pt.Status.ToLower()!="deleted")
                                                    .ToListAsync();

                    foreach (var task in tasksToCopy)
                    {
                        var newPageTask = new PageTask
                        {
                            Page = newPage, 
                            ParentTaskId = task.ParentTaskId,
                            Title = task.Title,
                            Status = task.Status
                        };
                        _context.PageTasks.Add(newPageTask);
                    }
                }
            }

            await _context.SaveChangesAsync();
            return CreatedAtAction(nameof(GetPageById), new { id = newPage.PageId }, new { PageId = newPage.PageId, PageDate = newPage.PageDate, DiaryId = newPage.DiaryNo });
        }
        [HttpGet("{id:int}")]
        public async Task<ActionResult<Page>> GetPageById(int id)
        {
            var page = await _context.Pages
                                     .Include(p => p.Diary) // Include Diary if you want to expose its details
                                     .Include(p => p.PageTasks) // Include related tasks
                                     .FirstOrDefaultAsync(p => p.PageId == id);

            if (page == null)
            {
                return NotFound();
            }
            return Ok(page);
        }

        [HttpGet("by-diary/{diaryId}")]
        public async Task<ActionResult<IEnumerable<Page>>> GetPagesByDiary(int diaryId)
        {
            var pages = await _context.Pages
                                      .Where(p => p.DiaryNo == diaryId)
                                      .OrderBy(p => p.PageDate)
                                      .ToListAsync();

            if (!pages.Any())
            {
                return NotFound($"No pages found for Diary ID {diaryId}.");
            }
            return Ok(pages);
        }

        // GET: api/pages/{pageId}/tasks
        [HttpGet("{pageId}/tasks")]
        public async Task<ActionResult<IEnumerable<PageTask>>> GetPageTasks(int pageId)
        {
            var tasks = await _context.PageTasks
                                      .Where(pt => pt.PageId == pageId)
                                      .ToListAsync();

            if (!tasks.Any())
            {
                return NotFound($"No tasks found for Page ID {pageId}.");
            }
           
            return Ok(tasks);
        }
        [HttpGet("by-date")]
        public async Task<IActionResult> GetPageByDate([FromQuery] int diaryId, [FromQuery] DateTime date)
        {
            var page = await _context.Pages
                .Where(p => p.DiaryNo == diaryId && p.PageDate.Date == date.Date)
                .FirstOrDefaultAsync();

            if (page == null)
            {
                return NotFound($"No page found for Diary ID {diaryId} on {date:yyyy-MM-dd}.");
            }

            return Ok(new
            {
                page.PageId,
                page.PageDate,
                page.DiaryNo
            });
        }
        [HttpPost("copy-tasks")]
        public async Task<IActionResult> CopyTasks([FromBody] CopyTasksDto copyDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            try
            {
                Console.WriteLine($"The source date is {copyDto.SourcePageDate} and target is {copyDto.TargetPageDate}");
                var sourcePage = await _context.Pages
                    .FirstOrDefaultAsync(p => p.PageDate.Date == copyDto.SourcePageDate.Date && p.DiaryNo == 1);
                if (sourcePage == null)
                {
                    return NotFound($"Source page for date {copyDto.SourcePageDate.ToShortDateString()} not found for Diary ID {1}.");
                }

                var targetPage = await _context.Pages
                    .FirstOrDefaultAsync(p => p.PageDate.Date == copyDto.TargetPageDate.Date && p.DiaryNo == 1);

                // If target page does not exist, create it (as per previous logic for creating new pages for today)
                if (targetPage == null)
                {
                    targetPage = new Page
                    {
                        DiaryNo = 1,
                        PageDate = copyDto.TargetPageDate.Date, // Store only date part
                      
                    };
                    _context.Pages.Add(targetPage);
                    await _context.SaveChangesAsync(); // Save to get the new targetPage.PageId
                }

                // Fetch tasks from the source page that are not 'Completed' or 'Deleted'
                // Assuming your PageTask model has a 'Status' property that can be compared to strings
                var tasksToCopy = await _context.PageTasks
                    .Where(pt => pt.PageId == sourcePage.PageId &&
                                 pt.Status.ToLower() != "completed" && // Case-insensitive comparison
                                 pt.Status.ToLower() != "deleted")
                    .AsNoTracking() // Use AsNoTracking for efficiency if you're not modifying them
                    .ToListAsync();

                if (!tasksToCopy.Any())
                {
                    return Ok("No uncompleted/undeleted tasks found to copy from the source page.");
                }

                foreach (var task in tasksToCopy)
                {
                    
                    var existingTask = await _context.PageTasks
                        .AnyAsync(pt => pt.PageId == targetPage.PageId &&
                                        pt.Title == task.Title &&
                                        pt.Status == task.Status); // Consider if status should be part of uniqueness

                    if (!existingTask)
                    {
                        var newPageTask = new PageTask
                        {
                            PageId = targetPage.PageId,
                            Title = task.Title,
                            Status = task.Status,
                            ParentTaskId = task.ParentTaskId, 
                        };
                        _context.PageTasks.Add(newPageTask);
                    }
                }

                await _context.SaveChangesAsync();

                return Ok($"Successfully copied {tasksToCopy.Count} uncompleted/undeleted tasks from {sourcePage.PageDate.ToShortDateString()} to {targetPage.PageDate.ToShortDateString()}.");
            }
            catch (Exception ex)
            {
               
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }
    
}
}