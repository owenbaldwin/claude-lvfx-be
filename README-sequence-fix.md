# Sequence Creation Fix

This branch fixes the 422 Unprocessable Entity error when creating new sequences in the application.

## Changes Made

1. **Updated the Sequences Controller**
   - Now handles both nested and non-nested parameter formats
   - Provides sensible defaults for required fields
   - Added comprehensive logging for debugging
   - Automatically generates a sequence number if not provided

2. **Updated the Sequence Model**
   - Changed uniqueness constraint from script_id to production_id
   - This allows sequences to be created without requiring an associated script

3. **Added Database Migration**
   - Removed the script_id + number uniqueness index
   - Added a production_id + number uniqueness index

## How to Apply the Fix

1. Pull this branch
2. Run the migration: `rails db:migrate`
3. Restart the server

## Testing

After applying these changes, you should be able to create new sequences both with and without an associated script. The sequence creation will now handle the following request formats:

### Nested Parameters Format:
```json
{
  "sequence": {
    "name": "My New Sequence",
    "number": 1,
    "prefix": "SEQ",
    "description": "Sequence description"
  }
}
```

### Non-nested Parameters Format:
```json
{
  "name": "My New Sequence",
  "number": 1,
  "prefix": "SEQ",
  "description": "Sequence description"
}
```

### Minimal Parameters:
The controller will now work even with minimal parameters, providing defaults as needed:
```json
{}
```
This will create a sequence with:
- Name: "New Sequence"
- Number: Auto-incremented (next available)
- Other fields: null
