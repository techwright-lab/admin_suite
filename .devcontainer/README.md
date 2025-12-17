# Dev Container Setup

This devcontainer configuration provides a complete development environment for Gleania with Selenium support for the rendered HTML service.

## Services

The devcontainer includes three services:

1. **rails-app**: The main Rails application container
   - Includes Chrome and all dependencies for Selenium
   - Can connect to remote Selenium Grid or use local ChromeDriver
   - Port 3000: Rails server

2. **postgres**: PostgreSQL database
   - Port 5432: PostgreSQL connection
   - Default credentials: postgres/postgres

3. **selenium**: Selenium Grid standalone Chrome
   - Port 4444: Selenium Grid Hub
   - Port 7900: VNC viewer (for debugging browser sessions)
   - Accessible at `http://selenium:4444` from within the container network

## Environment Variables

The following environment variables are automatically set:

- `SELENIUM_REMOTE_URL=http://selenium:4444` - Points to the Selenium Grid service
- `SELENIUM_HOST=selenium` - Hostname for Selenium Grid
- `DB_HOST=postgres` - PostgreSQL hostname

## Usage

1. Open the project in VS Code
2. When prompted, click "Reopen in Container" or use Command Palette: "Dev Containers: Reopen in Container"
3. Wait for the containers to build and start
4. The Rails app will automatically run `bundle install` and `rails db:prepare` on first startup

## Testing Selenium Connection

You can test that Selenium is working by running:

```bash
# In the rails-app container
bin/rails runner "puts Selenium::WebDriver.for(:remote, url: 'http://selenium:4444', options: Selenium::WebDriver::Chrome::Options.new).page_source.length"
```

Or test the rendered HTML service:

```bash
bin/rails runner "service = Scraping::RenderedHtmlFetcherService.new(JobListing.first); result = service.call; puts result[:success]"
```

## VNC Viewer (Optional)

To view browser sessions in real-time, you can connect to the VNC server:

- URL: `http://localhost:7900`
- Password: (none, password disabled for development)

## Troubleshooting

### Selenium connection issues

If the Rails app can't connect to Selenium:

1. Check that the selenium service is running: `docker ps | grep selenium`
2. Verify the service is healthy: `curl http://localhost:4444/wd/hub/status`
3. Check environment variables: `echo $SELENIUM_REMOTE_URL`

### Chrome not found

If Chrome is not found in the rails-app container:

1. Verify Chrome installation: `google-chrome --version`
2. Check Chrome dependencies: `ldd $(which google-chrome)`

### Database connection issues

If you can't connect to PostgreSQL:

1. Check that postgres service is running: `docker ps | grep postgres`
2. Verify connection: `psql -h postgres -U postgres -d gleania_development`
3. Check environment variables: `echo $DB_HOST`

