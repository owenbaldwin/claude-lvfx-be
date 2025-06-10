#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

puts "🧪 Testing improved SceneVerifierAgent with batching..."

# Find the script and create a new ScriptParse record
script = Script.find(6)
production = Production.find(6)

job_id = SecureRandom.uuid
script_parse = ScriptParse.create!(
  script: script,
  production: production,
  job_id: job_id,
  status: 'pending'
)

puts "Created ScriptParse ID: #{script_parse.id}"

# Run the job directly
begin
  puts "🚀 Starting AgenticScriptParserJob directly..."
  job = AgenticScriptParserJob.new
  job.perform(script_parse.id)

  # Check the results
  script_parse.reload
  puts "\n✅ Job completed!"
  puts "Status: #{script_parse.status}"
  puts "Error: #{script_parse.error}" if script_parse.error

  if script_parse.results_json
    scenes_count = script_parse.results_json.dig("scenes")&.length || 0
    puts "Scenes extracted: #{scenes_count}"
  end

rescue => e
  puts "\n❌ Job failed with error:"
  puts "#{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\n🏁 Test complete!"
