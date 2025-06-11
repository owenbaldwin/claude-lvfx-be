# Multi-Agent Script Parser

This system uses AI agents powered by GPT-4.1 nano to parse movie scripts and extract structured scene data for database storage.

## Overview

The multi-agent system consists of four specialized agents:

1. **ScriptParserAgent** - Main coordinator that orchestrates the entire parsing process
2. **SluglineExtractorAgent** - Extracts scene sluglines (headers) from the script text
3. **SceneExtractorAgent** - Extracts detailed scene data for each slugline
4. **SceneVerifierAgent** - Validates the structure of extracted scene data

## Architecture

```
ScriptParserAgent (Coordinator)
├── SluglineExtractorAgent (Extract sluglines from full script)
├── SceneExtractorAgent (Extract detailed scene data)
└── SceneVerifierAgent (Structural validation)
```

## Setup

1. Set your OpenAI API key:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

2. The system uses GPT-4.1 nano which requires no additional setup beyond the API key.

## Usage

### Background Job (Recommended)

Queue a script for parsing:

```ruby
# Parse a script asynchronously
AgenticScriptParserJob.perform_later(script_id, script_parse_id)
```

### Direct Usage

Parse a script synchronously:

```ruby
# Create the main parser agent
parser_agent = ScriptParserAgent.new

# Parse the script (returns true/false)
success = parser_agent.parse_script(script_id)
```

### Individual Agent Usage

You can also use individual agents for specific tasks:

```ruby
# Extract sluglines from entire script (no chunking)
slugline_agent = SluglineExtractorAgent.new
sluglines = slugline_agent.extract_sluglines(script_text)

# Extract scene data for a specific slugline
scene_agent = SceneExtractorAgent.new
scene_data = scene_agent.extract_scene_data_for_slugline(script_text, slugline, scene_number)

# Validate extracted scenes structure
verifier_agent = SceneVerifierAgent.new
validation = verifier_agent.verify_extracted_scenes(script_text, extracted_scenes)
```

## Data Flow

1. **Input**: Script with attached PDF file or raw text
2. **Processing**:
   - Extract all sluglines from complete script text (single API call)
   - Extract detailed scene data for each slugline
   - Validate structure of extracted scenes
3. **Output**: Structured JSON data saved to database via `ScriptJsonImporter`

## Key Features

### GPT-4.1 Nano Integration
- Uses `gpt-4.1-nano-2025-04-14` model
- High token limit (32,768) processes entire scripts at once
- No chunking required - maintains full script context
- Single-pass processing for better accuracy

### Enhanced Scene Number Handling
The system handles complex scene numbering patterns:
- Standard numbers: `1`, `2`, `3`
- Letter suffixes: `1A`, `1B`, `2A`, `2B`
- Roman numerals: `I`, `II`, `III`
- Continued scenes: `1 CONT'D`, `2 (CONTINUED)`

### Structural Validation
- Validates required fields (scene_number, int_ext, location, time)
- Checks data types and formats
- Identifies duplicate scene numbers
- Provides warnings without blocking successful parsing

## Expected JSON Format

The agents produce JSON data compatible with the existing `ScriptJsonImporter`:

```json
{
  "scenes": [
    {
      "scene_number": "1",
      "int_ext": "INT",
      "location": "COFFEE SHOP",
      "time": "DAY",
      "description": "A busy coffee shop scene with morning rush",
      "characters": ["SARAH", "DAVID"],
      "action_beats": [
        {
          "type": "action",
          "content": "Sarah enters the crowded coffee shop",
          "characters": ["SARAH"]
        },
        {
          "type": "dialogue",
          "content": "I'll have a large coffee, please.",
          "characters": ["SARAH"]
        }
      ],
      "original_slugline": "1. INT. COFFEE SHOP - DAY"
    }
  ]
}
```

## Testing

Run the test suite:

```ruby
# In Rails console or as a script
require_relative 'db/seeds/agentic_script_test'
```

## Configuration

### Model Settings
- **Model**: `gpt-4.1-nano-2025-04-14`
- **Temperature**: 0.1 (for consistent parsing)
- **Max Tokens**: 32,768 (handles feature-length scripts)
- **Processing**: Single-pass, no chunking

### Agent Configuration
Configured in `app/agents/application_agent.rb`:
- OpenAI API integration
- Error handling and retry logic
- Comprehensive logging

## Error Handling

The system includes:

- **Retry Logic**: Failed scene extractions are retried up to 3 times
- **JSON Validation**: All responses are validated before processing
- **Fallback Extraction**: Regex fallback for slugline extraction
- **Structural Validation**: Validates data integrity without complex AI verification
- **Graceful Degradation**: Continues processing even if some scenes fail
- **Comprehensive Logging**: Detailed logs for debugging and monitoring

## Database Integration

The system integrates with existing Rails models:

- `Script` - Stores the original script and processed JSON data
- `Scene` - Individual scenes with sluglines and metadata
- `ActionBeat` - Dialogue and action elements within scenes
- `Character` - Characters appearing in scenes
- `CharacterAppearance` - Links characters to scenes and action beats

Data is imported using the existing `ScriptJsonImporter` class.

## Performance Characteristics

### Single-Pass Processing
- Entire script processed in one API call per agent
- No chunking eliminates multiple API rounds
- Full context maintained throughout parsing
- Better scene boundary detection

### Token Efficiency
- 32,768 token limit handles most feature scripts
- Efficient prompts minimize processing time
- GPT-4.1 nano is cost-effective
- Reduced API calls compared to chunked approaches

### Async Processing
- Background jobs prevent timeouts
- Non-blocking API endpoints
- Scalable for multiple scripts

## Logging & Monitoring

All agents provide detailed logging:

```
[ScriptParserAgent] 🎬 Starting script parsing for Script#123
[SluglineExtractorAgent] Found 24 sluglines (no chunking used)
[SceneExtractorAgent] ✅ Successfully extracted scene 1
[SceneVerifierAgent] Structural validation complete: PASSED
```

Enable debug logging in development:
```ruby
# config/environments/development.rb
config.log_level = :debug
```

## Troubleshooting

### Common Issues

1. **Missing API Key**
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. **PDF Extraction Failures**
   - Ensure PDF files are readable and not password-protected
   - Check PDF file attachment is properly saved

3. **JSON Parsing Errors**
   - Check agent prompts and response validation
   - Review logs for specific error details

4. **Database Import Errors**
   - Verify foreign key constraints
   - Check required field validations
   - Ensure transaction integrity

5. **Scene Matching Issues**
   - Review slugline normalization logic
   - Check scene number parsing patterns

### Debugging Steps

1. **Check Logs**: Review agent-specific log entries
2. **Test Individual Agents**: Use agents separately to isolate issues
3. **Validate JSON**: Ensure API responses are valid JSON
4. **Database Constraints**: Verify model validations and constraints

## API Integration

### Background Job Status
Check parsing status:
```ruby
script_parse = ScriptParse.find_by(job_id: job_id)
puts script_parse.status # 'pending', 'processing', 'completed', 'failed'
```

### Direct API Usage
```ruby
# Initialize parser
parser = ScriptParserAgent.new

# Process script
success = parser.parse_script(script_id)

if success
  puts "Script parsed successfully"
else
  puts "Script parsing failed - check logs"
end
```

## Production Considerations

### Rate Limiting
- GPT-4.1 nano has higher rate limits
- Built-in retry logic handles temporary failures
- Async processing prevents request timeouts

### Error Recovery
- Failed scenes are logged but don't stop processing
- Structural validation provides data integrity
- Database transactions ensure consistency

### Monitoring
- Comprehensive logging for production debugging
- Error tracking through Rails logs
- Performance metrics through agent timing

## System Requirements

- Ruby on Rails application
- OpenAI API key with GPT-4.1 nano access
- PDF processing capabilities (pdf-reader gem)
- Background job processing (ActiveJob)
- PostgreSQL database (for JSON fields)

---

The multi-agent script parser provides a robust, scalable solution for converting movie scripts into structured data using the latest AI capabilities.
