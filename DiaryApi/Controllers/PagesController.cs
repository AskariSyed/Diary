using DiaryApi.Data;
using DiaryApi.Dtos;
using DiaryApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System; // Make sure this is present for DateTime operations
using System.Linq;
using System.Collections.Generic; // Make sure this is present

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

        // POST: api/pages/create
        [HttpPost("create")]
        public async Task<IActionResult> CreatePage([FromBody] CreatePageDto createPageDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // 1. Verify Diary Exists
            var diaryExists = await _context.Diaries.AnyAsync(d => d.Id == createPageDto.DiaryNo); // Using DiaryId as suggested earlier
            if (!diaryExists)
            {
                return NotFound($"Diary with ID {createPageDto.DiaryNo} not found.");
            }

            // 2. Check for existing page on the exact date for this diary
            var existingPageOnDate = await _context.Pages
                                                .AnyAsync(p => p.DiaryNo == createPageDto.DiaryNo &&
                                                               p.PageDate.Date == createPageDto.PageDate.Date); // Ensure comparing dates only

            if (existingPageOnDate)
            {
                return Conflict($"A page already exists for Diary ID {createPageDto.DiaryNo} on {createPageDto.PageDate.Date:yyyy-MM-dd}.");
            }


            // 3. Create the new Page
            var newPage = new Page
            {
                PageDate = createPageDto.PageDate.Date, // Store only the date part
                   DiaryNo = createPageDto.DiaryNo // Using DiaryId
            };

            _context.Pages.Add(newPage);

            // 4. Find the last day with pages for this diary *before* the new page's date
            //    We need to get the latest *distinct* date that has pages
            var lastPageDate = await _context.Pages
                                            .Where(p => p.DiaryNo == createPageDto.DiaryNo && p.PageDate < createPageDto.PageDate.Date)
                                            .Select(p => p.PageDate)
                                            .OrderByDescending(pd => pd)
                                            .FirstOrDefaultAsync();

            if (lastPageDate != default(DateTime)) // Check if a previous date was found
            {
                // 5. Get all pages from that specific last date for the current diary
                var pagesFromLastDay = await _context.Pages
                                                    .Where(p => p.DiaryNo == createPageDto.DiaryNo && p.PageDate == lastPageDate)
                                                    .Select(p => p.PageId) // Select only PageIds to get tasks
                                                    .ToListAsync();

                if (pagesFromLastDay.Any())
                {
                    // 6. Get all uncompleted tasks from ALL pages on that last day
                    var tasksToCopy = await _context.PageTasks
                                                    .Where(pt => pagesFromLastDay.Contains(pt.PageId) &&
                                                                 pt.Status.ToLower() != "completed")
                                                    .ToListAsync();

                    // 7. Copy tasks to the new page
                    foreach (var task in tasksToCopy)
                    {
                        var newPageTask = new PageTask
                        {
                            Page = newPage, // EF Core will link this to the newPage after SaveChanges
                            ParentTaskId = task.ParentTaskId, // Retain link to the original DiaryTask if applicable
                            Title = task.Title,
                            Status = task.Status
                        };
                        _context.PageTasks.Add(newPageTask);
                    }
                }
            }

            await _context.SaveChangesAsync();

            // Return a more descriptive success message, perhaps including the full new page object
            // Or a DTO if you have one for Page retrieval. For now, just the ID.
            return CreatedAtAction(nameof(GetPageById), new { id = newPage.PageId }, new { PageId = newPage.PageId, PageDate = newPage.PageDate, DiaryId = newPage.DiaryNo });
        }

        // GET: api/pages/{id} (Added for CreatedAtAction to work properly)
        [HttpGet("{id}")]
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

            // You might want to return a DTO here instead of the raw model
            // For simplicity, returning the model directly for now.
            return Ok(page);
        }

        // You'll likely want other endpoints for Pages as well:
        // GET: api/pages/by-diary/{diaryId}
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
            // Map to a TaskDto if you have one for PageTask
            return Ok(tasks);
        }
    }
}