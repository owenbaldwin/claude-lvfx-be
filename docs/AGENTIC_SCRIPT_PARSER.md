# Multi-Agent Script Parser

This system uses AI agents to parse movie scripts and extract structured scene data for database storage.

## Overview

The multi-agent system consists of four specialized agents:

1. **ScriptParserAgent** - Main coordinator that orchestrates the entire parsing process
2. **SluglineExtractorAgent** - Extracts scene sluglines (headers) from the script text
3. **SceneExtractorAgent** - Extracts detailed scene data for each slugline
4. **SceneVerifierAgent** - Verifies that all scenes were correctly extracted

## Architecture

```
ScriptParserAgent (Coordinator)
├── SluglineExtractorAgent (Extract sluglines)
├── SceneExtractorAgent (Extract scene data)
└── SceneVerifierAgent (Verify completeness)
```

## Setup

1. Add Active Agent to your Gemfile:
```ruby
gem "active_agent", "~> 0.1.0"
```

2. Install dependencies:
```bash
bundle install
```

3. Set your OpenAI API key:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

## Usage

### Background Job (Recommended)

Queue a script for parsing:

```ruby
# Parse a script asynchronously
AgenticScriptParserJob.perform_later(script_id)
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
# Extract sluglines only
slugline_agent = SluglineExtractorAgent.new
sluglines = slugline_agent.extract_sluglines_from_script(script_text)

# Extract scene data for a specific slugline
scene_agent = SceneExtractorAgent.new
scene_data = scene_agent.extract_scene_data_for_slugline(script_text, slugline, scene_number)

# Verify extracted scenes
verifier_agent = SceneVerifierAgent.new
verification = verifier_agent.verify_extracted_scenes(script_text, extracted_scenes)
```

## Data Flow

1. **Input**: Script with attached PDF file or raw text
2. **Processing**:
   - Extract sluglines from script text
   - Extract detailed scene data for each slugline
   - Verify all scenes were captured
3. **Output**: Structured JSON data saved to database via `ScriptJsonImporter`

## Expected JSON Format

The agents produce JSON data compatible with the existing `ScriptJsonImporter`:

```json
{
  "scenes": [
    {
      "scene_number": 1,
      "int_ext": "INT",
      "location": "COFFEE SHOP",
      "time": "DAY",
      "description": "Scene description...",
      "characters": ["SARAH", "DAVID"],
      "action_beats": [
        {
          "type": "action",
          "content": "Action description...",
          "characters": []
        },
        {
          "type": "dialogue",
          "content": "Character dialogue...",
          "characters": ["SARAH"]
        }
      ]
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

Agents are configured in `config/initializers/active_agent.rb`:

- OpenAI API key
- Default model (GPT-4)
- Temperature settings
- Token limits
- Logging configuration

## Error Handling

The system includes:

- **Retry logic**: Failed scene extractions are retried up to 3 times
- **Validation**: JSON responses are validated before processing
- **Logging**: Comprehensive logging for debugging and monitoring
- **Graceful degradation**: Continues processing even if some scenes fail

## Database Integration

The system integrates with existing Rails models:

- `Script` - Stores the original script and JSON data
- `Scene` - Individual scenes with sluglines and metadata
- `ActionBeat` - Dialogue and action elements within scenes
- `Character` - Characters appearing in scenes
- `CharacterAppearance` - Links characters to scenes and action beats

## Performance Considerations

- **Async Processing**: Use `AgenticScriptParserJob` for large scripts
- **Token Limits**: Configure appropriate max_tokens based on script length
- **Rate Limiting**: Be mindful of OpenAI API rate limits
- **Database Transactions**: All imports are wrapped in transactions

## Troubleshooting

Common issues:

1. **Missing API Key**: Ensure `OPENAI_API_KEY` is set
2. **Invalid JSON**: Check agent prompts and response parsing
3. **PDF Extraction**: Ensure PDF files are readable and not password-protected
4. **Database Errors**: Check foreign key constraints and required fields

## Logging

All agents log their activities:

```ruby
# Enable debug logging in development
config.log_level = :debug
```

Log entries are prefixed with agent class names for easy filtering.
