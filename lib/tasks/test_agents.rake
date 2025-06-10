namespace :agents do
  desc "Test the multi-agent script parsing system"
  task test: :environment do
    puts "🤖 Testing Multi-Agent Script Parsing System"
    puts "=" * 50

    # Check environment
    if ENV['OPENAI_API_KEY'].blank?
      puts "❌ OPENAI_API_KEY not set. Please set your OpenAI API key:"
      puts "   export OPENAI_API_KEY='your-api-key-here'"
      exit 1
    end

    # Load the test script
    require_relative '../../db/seeds/agentic_script_test'

    puts "\n🎉 Test completed successfully!"
  end

  desc "Parse a specific script with agents"
  task :parse, [:script_id] => :environment do |t, args|
    script_id = args[:script_id]

    if script_id.blank?
      puts "Usage: rake agents:parse[SCRIPT_ID]"
      exit 1
    end

    puts "🤖 Parsing Script##{script_id} with multi-agent system..."

    begin
      script = Script.find(script_id)
      puts "📄 Found script: #{script.title}"

      # Queue the job
      AgenticScriptParserJob.perform_later(script_id)
      puts "✅ Parsing job queued successfully!"
      puts "   Check the job queue and logs for progress."

    rescue ActiveRecord::RecordNotFound
      puts "❌ Script##{script_id} not found"
      exit 1
    rescue => e
      puts "❌ Error: #{e.message}"
      exit 1
    end
  end

  desc "Test individual agents with sample text"
  task test_individual: :environment do
    sample_text = <<~SCRIPT
      INT. COFFEE SHOP - DAY

      SARAH sits at a table with her laptop.

      SARAH
      This is a test dialogue.

      EXT. PARK - LATER

      DAVID walks through the park.
    SCRIPT

    puts "🧪 Testing Individual Agents"
    puts "=" * 30

    # Test SluglineExtractorAgent
    puts "\n1. Testing SluglineExtractorAgent..."
    slugline_agent = SluglineExtractorAgent.new
    sluglines = slugline_agent.extract_sluglines_from_script(sample_text)
    puts "   Found sluglines: #{sluglines.inspect}"

    # Test SceneExtractorAgent
    if sluglines.any?
      puts "\n2. Testing SceneExtractorAgent..."
      scene_agent = SceneExtractorAgent.new
      scene_data = scene_agent.extract_scene_data_for_slugline(sample_text, sluglines.first, 1)

      if scene_data
        puts "   ✅ Scene extraction successful"
        puts "   Keys: #{scene_data.keys}"
      else
        puts "   ❌ Scene extraction failed"
      end
    end

    puts "\n✅ Individual agent testing completed!"
  end
end
