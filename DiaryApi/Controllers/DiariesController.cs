using DiaryApi.Dtos;
using DiaryApi.Models;
using DiaryApi.Data; // Import your DbContext namespace
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore; // Required for ToListAsync, FirstOrDefaultAsync, etc.
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks; // Required for async/await

namespace DiaryApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DiariesController : ControllerBase
    {
        private readonly AppDbContext _context; // Declare your DbContext

        public DiariesController(AppDbContext context) // Inject AppDbContext via constructor
        {
            _context = context;
        }

        // GET: api/Diaries
        [HttpGet]
        public async Task<ActionResult<IEnumerable<DiaryDto>>> GetDiaries()
        {
            var diaries = await _context.Diaries.ToListAsync();
            var diaryDtos = diaries.Select(d => new DiaryDto
            {
                Id = d.Id,
                CreatedDate = d.CreatedDate,
                OwnerName = d.OwnerName
            }).ToList();

            return Ok(diaryDtos);
        }
        [HttpGet("{id}")]
        public async Task<ActionResult<DiaryDto>> GetDiary(int id)
        {
            var diary = await _context.Diaries.FirstOrDefaultAsync(d => d.Id == id);

            if (diary == null)
            {
                return NotFound(); 
            }
            var diaryDto = new DiaryDto
            {
                Id = diary.Id,
                CreatedDate = diary.CreatedDate,
                OwnerName = diary.OwnerName
            };

            return Ok(diaryDto); 
        }
        [HttpPost]
        public async Task<ActionResult<DiaryDto>> CreateDiary([FromBody] DiaryCreateDto diaryCreateDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            var newDiary = new Diary
            {
                OwnerName = diaryCreateDto.OwnerName
            };

            _context.Diaries.Add(newDiary);
            await _context.SaveChangesAsync(); 

            // Map the newly created Diary model (which now has its Id and CreatedDate from DB) to DiaryDto
            var newDiaryDto = new DiaryDto
            {
                Id = newDiary.Id,
                CreatedDate = newDiary.CreatedDate,
                OwnerName = newDiary.OwnerName
            };

            // Return 201 Created with the location of the new resource
            return CreatedAtAction(nameof(GetDiary), new { id = newDiary.Id }, newDiaryDto);
        }

        // PUT: api/Diaries/5
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateDiary(int id, [FromBody] DiaryDto diaryDto)
        {
            if (id != diaryDto.Id)
            {
                return BadRequest(); // 400 Bad Request if ID in URL doesn't match ID in body
            }

            var existingDiary = await _context.Diaries.FirstOrDefaultAsync(d => d.Id == id);

            if (existingDiary == null)
            {
                return NotFound(); // 404 Not Found
            }

            // Update properties from the DTO
            existingDiary.OwnerName = diaryDto.OwnerName;
            // existingDiary.CreatedDate = diaryDto.CreatedDate; // Typically CreatedDate is not updated via PUT

            try
            {
                await _context.SaveChangesAsync(); // Save changes to the database
            }
            catch (DbUpdateConcurrencyException)
            {
                // This block handles scenarios where the entity might have been deleted by another process
                // between being fetched and saved. More robust handling might involve
                // checking if the entity still exists:
                if (!await _context.Diaries.AnyAsync(e => e.Id == id))
                {
                    return NotFound();
                }
                else
                {
                    throw; // Re-throw other concurrency exceptions
                }
            }

            return NoContent(); // 204 No Content for successful update
        }

        // DELETE: api/Diaries/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDiary(int id)
        {
            var diaryToRemove = await _context.Diaries.FirstOrDefaultAsync(d => d.Id == id);

            if (diaryToRemove == null)
            {
                return NotFound(); // 404 Not Found
            }

            _context.Diaries.Remove(diaryToRemove); // Mark for removal
            await _context.SaveChangesAsync(); // Save changes to the database (performs the delete)

            return NoContent(); // 204 No Content for successful deletion
        }
    }
}