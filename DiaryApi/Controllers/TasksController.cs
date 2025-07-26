using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DiaryApi.Data;
using DiaryApi.Models;
using DiaryApi.Dtos;
using System.Threading.Tasks;
using System.Linq;
using System.Collections.Generic; // Added for List<PageTask>

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

        // POST: api/tasks/create
        [HttpPost("create")]
        public async Task<IActionResult> CreateTask([FromBody] CreateTaskDto createTaskDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
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

        // PUT: api/tasks/pagetask/{pageTaskId}/status
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

        // PUT: api/tasks/pagetask/{pageTaskId}/title
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

        // GET: api/tasks/allpagetasks
        /// <summary>
        /// Retrieves all PageTasks, sorted by PageId, returning only necessary fields.
        /// </summary>
        /// <returns>A list of PageTaskResponseDto objects.</returns>
        [HttpGet("allpagetasks")]
        public async Task<ActionResult<IEnumerable<PageTaskResponseDto>>> GetAllPageTasksSortedByPageId()
        {
            var pageTasks = await _context.PageTasks
                                          .OrderBy(pt => pt.PageId)
                                          .Select(pt => new PageTaskResponseDto // Project to DTO
                                          {
                                              Id = pt.Id,
                                              PageId = pt.PageId,
                                              ParentTaskId = pt.ParentTaskId,
                                              Status = pt.Status,
                                              Title = pt.Title
                                          })
                                          .ToListAsync();

            return Ok(pageTasks);
        }

        // NEW: DELETE endpoint for PageTasks
        // DELETE: api/tasks/pagetask/{pageTaskId}
        /// <summary>
        /// Deletes a specific PageTask by its ID.
        /// </summary>
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

            return NoContent(); // 204 No Content indicates successful deletion
        }
    }
}
