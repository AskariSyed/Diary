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

    }
}