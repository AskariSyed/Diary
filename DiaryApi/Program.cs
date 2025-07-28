using Microsoft.EntityFrameworkCore;
using DiaryApi.Data;

var builder = WebApplication.CreateBuilder(args);

// ✅ Configure Kestrel to listen on 0.0.0.0 (all network interfaces)
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.ListenAnyIP(5158); // HTTP
    serverOptions.ListenAnyIP(7050, listenOptions =>
    {
        listenOptions.UseHttps(); // HTTPS
    });
});

// Add DbContext to the services container.
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}


app.UseAuthorization();
app.MapControllers();

app.Run();
