# Multi-Agent Script Parsing System Test
puts "🤖 Testing Multi-Agent Script Parsing System"

# Check if OpenAI API key is configured
if ENV['OPENAI_API_KEY'].blank?
  puts "❌ OPENAI_API_KEY not configured. Please set your OpenAI API key."
  puts "   Export it with: export OPENAI_API_KEY='your-api-key-here'"
  exit 1
else
  puts "✅ OpenAI API key configured"
end

# Find or create test data
puts "\n📋 Finding test data..."

# Find existing production and script
production = Production.first
script = Script.first

if production.nil?
  puts "❌ No production found in database. Please create a production first."
  puts "   You can create one through the web interface or Rails console."
  exit 1
end

if script.nil?
  puts "❌ No script found in database. Please create a script first."
  puts "   You can create one through the web interface or Rails console."
  exit 1
end

puts "✅ Using Production: #{production.title} (ID: #{production.id})"
puts "✅ Using Script: #{script.title} (ID: #{script.id})"

# Test the multi-agent parsing system
puts "\n🔄 Testing multi-agent parsing system..."

begin
  # Create or find existing script parse
  script_parse = ScriptParse.find_or_create_by(
    production: production,
    script: script
  ) do |sp|
    sp.job_id = SecureRandom.uuid
    sp.status = 'pending'
  end

  puts "✅ Using ScriptParse record: #{script_parse.job_id}"

  # Test individual agents
  puts "\n🧪 Testing individual agents..."

  # Test text extraction
  begin
    text_content = script.pdf_file.attached? ?
      script.pdf_file.download :
      "INT. TEST SCENE - DAY\n\nThis is a test scene for agent parsing."

    puts "✅ Text extraction: #{text_content.length} characters"
  rescue => e
    puts "⚠️  Text extraction warning: #{e.message}"
    text_content = "INT. TEST SCENE - DAY\n\nThis is a test scene for agent parsing."
  end

  # Test SluglineExtractorAgent
  begin
    slugline_agent = SluglineExtractorAgent.new
    sluglines = slugline_agent.extract_sluglines_from_script(text_content)
    puts "✅ SluglineExtractorAgent: Found #{sluglines&.length || 0} sluglines"
  rescue => e
    puts "❌ SluglineExtractorAgent error: #{e.message}"
  end

  # Test SceneExtractorAgent
  begin
    scene_agent = SceneExtractorAgent.new
    if sluglines&.any?
      sample_slugline = sluglines.first
      scene_data = scene_agent.extract_scene_data_for_slugline(text_content, sample_slugline, 1)
      puts "✅ SceneExtractorAgent: Extracted scene data for '#{sample_slugline}'"
    else
      puts "⚠️  SceneExtractorAgent: No sluglines available for testing"
    end
  rescue => e
    puts "❌ SceneExtractorAgent error: #{e.message}"
  end

  # Start the full parsing job
  puts "\n🔄 Starting full parsing job..."

  # Reset script parse status
  script_parse.update!(status: 'pending', error: nil, results_json: nil)

  # Start the parsing job
  job = AgenticScriptParserJob.perform_later(script_parse.id)
  puts "✅ Queued AgenticScriptParserJob"

  # Wait a moment and check status
  sleep(3)

  script_parse.reload
  puts "📊 Current parse status: #{script_parse.status}"

  if script_parse.error.present?
    puts "❌ Parse error: #{script_parse.error}"
  end

  if script_parse.results_json.present?
    puts "✅ Parse results available:"
    puts "   - Sluglines found: #{script_parse.results_json['sluglines']&.length || 0}"
    puts "   - Scenes extracted: #{script_parse.results_json['scenes']&.length || 0}"
    puts "   - Verification passed: #{script_parse.results_json['verification_passed'] ? 'Yes' : 'No'}"
  end

  puts "\n🎉 Multi-agent parsing test completed!"
  puts "   You can check the results by calling:"
  puts "   GET /api/v1/productions/#{production.id}/scripts/#{script.id}/parse_status"

rescue => e
  puts "❌ Error during parsing test: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
