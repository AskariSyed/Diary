using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DiaryApi.Data;
using DiaryApi.Models;
using DiaryApi.Dtos;
using System.Threading.Tasks;
using System.Linq;
using System.Collections.Generic;

namespace DiaryApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TasksController : ControllerBase
    {
        private readonly AppDbContext _context;

        public TasksController(AppDbContext context)
        {
            _context = context;
        }
        [HttpPost("create")]
        public async Task<IActionResult> CreateTask([FromBody] CreateTaskDto createTaskDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            if (createTaskDto.Title.Length >= 255)
            {
                return BadRequest("Task title must be less than 255 characters.");
            }


            var pageExists = await _context.Pages.AnyAsync(p => p.PageId == createTaskDto.PageId);
            if (!pageExists)
            {
                return NotFound($"Page with ID {createTaskDto.PageId} not found.");
            }

            var parentTask = new DiaryTask
            {
                Title = createTaskDto.Title,
                Status = createTaskDto.Status
            };

            var pageTask = new PageTask
            {
                PageId = createTaskDto.PageId,
                ParentTask = parentTask,
                Title = createTaskDto.Title,
                Status = createTaskDto.Status
            };

            _context.DiaryTasks.Add(parentTask);
            _context.PageTasks.Add(pageTask);
            await _context.SaveChangesAsync();

            return Ok(new { TaskId = parentTask.Id, PageTaskId = pageTask.Id });
        }
        [HttpPut("pagetask/{pageTaskId}/status")]
        public async Task<IActionResult> UpdatePageTaskStatus(int pageTaskId, [FromBody] UpdateTaskStatusDto updateDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var pageTask = await _context.PageTasks.FindAsync(pageTaskId);

            if (pageTask == null)
            {
                return NotFound();
            }

            pageTask.Status = updateDto.Status;
            await _context.SaveChangesAsync();

            return NoContent();
        }
        [HttpPut("pagetask/{pageTaskId}/title")]
        public async Task<IActionResult> UpdatePageTaskTitle(int pageTaskId, [FromBody] UpdateTaskTitleDto updateDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var pageTask = await _context.PageTasks.FindAsync(pageTaskId);

            if (pageTask == null)
            {
                return NotFound();
            }

            pageTask.Title = updateDto.Title;
            await _context.SaveChangesAsync();

            return NoContent();
        }
        [HttpGet("allpagetasks")]
        public async Task<ActionResult<IEnumerable<PageTaskResponseDto>>> GetAllPageTasksSortedByPageId()
        {
            var pageTasks = await _context.PageTasks
                                          .Include(pt => pt.Page)
                                          .Include(pt => pt.ParentTask)
                                          .OrderBy(pt => pt.PageId)
                                          .Select(pt => new PageTaskResponseDto
                                          {
                                              Id = pt.Id,
                                              PageId = pt.PageId,
                                              ParentTaskId = pt.ParentTaskId,
                                              Status = pt.Status,
                                              Title = pt.Title,
                                              PageDate = pt.Page.PageDate,
                                              ParentTaskCreatedAt = pt.ParentTask.CreatedAt
                                          })
                                          .ToListAsync();

            return Ok(pageTasks);
        }
        [HttpGet("search")]
        public async Task<ActionResult<IEnumerable<PageTaskResponseDto>>> SearchPageTasks(
    [FromQuery] int? pageId,
    [FromQuery] DateTime? pageDate,
    [FromQuery] string? title)
        {
            IQueryable<PageTask> query = _context.PageTasks
                .Include(pt => pt.Page)
                .Include(pt => pt.ParentTask);

            if (pageId.HasValue)
            {
                query = query.Where(pt => pt.PageId == pageId.Value);
            }

            if (pageDate.HasValue)
            {
                query = query.Where(pt => pt.Page.PageDate.Date == pageDate.Value.Date);
            }

            if (!string.IsNullOrEmpty(title))
            {
                string lowerTitle = title.ToLower();
                query = query.Where(pt => pt.Title.ToLower().Contains(lowerTitle));
            }

            var result = await query
                .OrderBy(pt => pt.PageId)
                .Select(pt => new PageTaskResponseDto
                {
                    Id = pt.Id,
                    PageId = pt.PageId,
                    ParentTaskId = pt.ParentTaskId,
                    Status = pt.Status,
                    Title = pt.Title,
                    PageDate = pt.Page.PageDate,
                    ParentTaskCreatedAt = pt.ParentTask.CreatedAt
                })
                .ToListAsync();

            return Ok(result);
        }


        /// <param name="pageTaskId">The ID of the PageTask to delete.</param>
        /// <returns>NoContent if successful, NotFound if the task does not exist.</returns>
        [HttpDelete("pagetask/{pageTaskId}")]
        public async Task<IActionResult> DeletePageTask(int pageTaskId)
        {
            var pageTask = await _context.PageTasks.FindAsync(pageTaskId);
            if (pageTask == null)
            {
                return NotFound();
            }

            _context.PageTasks.Remove(pageTask);
            await _context.SaveChangesAsync();

            return NoContent();
        }
        [HttpGet("task-history/by-parent/{parentTaskId}")]
        public async Task<IActionResult> GetTaskHistoryByParentTaskId(int parentTaskId)
        {
            var history = await _context.PageTasks
                                        .Include(pt => pt.Page)
                                        .Include(pt => pt.ParentTask) // Ensure ParentTask is included
                                        .Where(pt => pt.ParentTaskId == parentTaskId)
                                        .OrderBy(pt => pt.Page.PageDate)
                                        .Select(pt => new TaskHistoryDto
                                        {
                                            PageTaskId = pt.Id,
                                            PageId = pt.PageId,
                                            PageDate = pt.Page.PageDate,
                                            Title = pt.Title,
                                            Status = pt.Status,
                                            ParentTaskCreatedAt = pt.ParentTask.CreatedAt // Added this line
                                        })
                                        .ToListAsync();

            if (!history.Any())
            {
                return NotFound($"No task history found for ParentTask ID {parentTaskId}.");
            }

            return Ok(history);
        }

        [HttpGet("task-history/by-page-task/{pageTaskId}")]
        public async Task<IActionResult> GetTaskHistoryByPageTaskId(int pageTaskId)
        {
            var pageTask = await _context.PageTasks.FindAsync(pageTaskId);
            if (pageTask == null)
            {
                return NotFound($"PageTask with ID {pageTaskId} not found.");
            }

            return await GetTaskHistoryByParentTaskId(pageTask.ParentTaskId);
        }
        [HttpPut("pagetask/{pageTaskId}/status/today")]
        public async Task<IActionResult> ChangeStatusToTodayPage(int pageTaskId, [FromBody] UpdateTaskStatusDto updateDto)
        {
            Console.WriteLine("Hit received to update");

            if (!ModelState.IsValid)
            {
                Console.WriteLine("Invalid request to update");
                return BadRequest(ModelState);
            }

            var originalPageTask = await _context.PageTasks
                                                 .Include(pt => pt.Page)
                                                 .Include(pt => pt.ParentTask)
                                                 .FirstOrDefaultAsync(pt => pt.Id == pageTaskId);

            if (originalPageTask == null)
            {
                Console.WriteLine("PageTask not found");
                return NotFound($"PageTask with ID {pageTaskId} not found.");
            }

            DateTime today = DateTime.Today;
            DateTime taskDate = originalPageTask.Page.PageDate.Date;
            Console.WriteLine($"Task Date: {taskDate}, Today: {today}, Comparison: {taskDate.CompareTo(today)}");

            if (taskDate > today)
            {
                // Future task, just update the status
                Console.WriteLine("Updating future task");
                originalPageTask.Status = updateDto.Status;
                await _context.SaveChangesAsync();

                return Ok(new { Message = "Status updated for future task." });
            }

            if (taskDate == today)
            {
                // Already on today's page, update status
                Console.WriteLine("Updating task on today's page");
                originalPageTask.Status = updateDto.Status;
                await _context.SaveChangesAsync();

                return Ok(new { Message = "Status updated on existing task for today's page." });
            }

            // The task is from a past page, move it to today's page
            Console.WriteLine("Moving past task to today's page");

            var todayPage = await _context.Pages.FirstOrDefaultAsync(p => p.PageDate.Date == today);
            if (todayPage == null)
            {
                Console.WriteLine("Creating today's page");
                todayPage = new Page { PageDate = today };
                _context.Pages.Add(todayPage);
                await _context.SaveChangesAsync();
            }

            var existingTodayTask = await _context.PageTasks
                                                  .FirstOrDefaultAsync(pt => pt.PageId == todayPage.PageId &&
                                                                             pt.ParentTaskId == originalPageTask.ParentTaskId);

            if (existingTodayTask != null)
            {
                Console.WriteLine("Task already exists on today's page");
                existingTodayTask.Status = updateDto.Status;
                await _context.SaveChangesAsync();

                return Ok(new { NewPageTaskId = existingTodayTask.Id, Message = "Existing task's status updated on today's page." });
            }

            var newPageTask = new PageTask
            {
                PageId = todayPage.PageId,
                ParentTaskId = originalPageTask.ParentTaskId,
                Title = originalPageTask.Title,
                Status = updateDto.Status
            };

            _context.PageTasks.Add(newPageTask);
            await _context.SaveChangesAsync();

            return Ok(new { NewPageTaskId = newPageTask.Id, Message = "Task copied and status updated on today's page." });
        }

    }
}
