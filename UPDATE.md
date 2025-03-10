# Content Structure Update

This branch implements a comprehensive update to the content structure in the LVFX backend, specifically enhancing the models, relationships, and API endpoints for sequences, scenes, action beats, and shots.

## 1. Model Updates

All models have been enhanced with:
- Proper associations between related models
- Required field validations
- Data type enforcements
- Nested relationships

### Sequences
- Added `production_id` foreign key
- Changed `number` from string to integer
- Added `prefix` field
- Ensured uniqueness within a script

### Scenes
- Added `script_id` and `production_id` foreign keys
- Changed `number` from string to integer
- Renamed `setting` to `location` and `time_of_day` to `day_night`
- Added `int_ext` field with 'interior'/'exterior' enum
- Added `length` field
- Ensured uniqueness within a sequence

### Action Beats
- Added `script_id`, `production_id`, and `sequence_id` foreign keys
- Renamed `order_number` to `number`
- Added `beat_type` field with 'action'/'dialogue' enum (note: avoiding Rails STI 'type' column name)
- Added `text` field for the main content
- Made description optional
- Ensured uniqueness within a scene

### Shots
- Added `script_id`, `production_id`, `scene_id`, and `sequence_id` foreign keys
- Changed `number` from string to integer
- Added `vfx` field with 'yes'/'no' enum
- Added `duration` field
- Made description, camera_angle, and camera_movement required
- Ensured uniqueness within an action beat

## 2. Database Migrations

Created four migrations to update the tables:
- `20250310000101_update_sequences.rb`
- `20250310000102_update_scenes.rb`
- `20250310000103_update_action_beats.rb`
- `20250310000104_update_shots.rb`

These migrations add all the necessary fields, foreign keys, and indexes for proper database relationships and performance.

> **Important:** We named the action beat type field `beat_type` instead of `type` to avoid conflicts with Rails Single Table Inheritance (STI) which reserves the column name "type".

## 3. Route Structure Simplification

The URL structure has been simplified by removing script references from the route paths:

**Original structure:**
```
/api/v1/productions/:production_id/scripts/:script_id/sequences/:sequence_id/...
```

**New simplified structure:**
```
/api/v1/productions/:production_id/sequences/:sequence_id/...
```

While scripts are no longer part of the URL, each content element (sequence, scene, action beat, shot) still maintains its `script_id` relationship in the database. Controllers have been updated to:

1. Fetch the appropriate script from related models
2. Allow `script_id` to be passed as a parameter when needed
3. Maintain the same hierarchical data structure without requiring script specification in the URL

## 4. Controller Updates

Updated all controllers to support the new model structure:
- Added proper relation handling
- Updated strong parameters to include new fields
- Maintained RESTful API design
- Ensured proper authentication and authorization
- Added error handling
- Removed script dependency from URL parameters

## 5. Testing

Added comprehensive test suite:
- Model specs for all updated models
- FactoryBot factories for test data
- Request specs for API endpoints
- Validation tests for required fields and associations

## How to Apply the Update

1. Pull the branch
2. Run database migrations:
   ```
   rails db:migrate
   ```
3. Run tests to ensure everything is working correctly:
   ```
   rspec
   ```

## API Endpoints

The update simplifies the API endpoint structure:

```
GET    /api/v1/productions/:production_id/sequences
POST   /api/v1/productions/:production_id/sequences
GET    /api/v1/productions/:production_id/sequences/:id
PUT    /api/v1/productions/:production_id/sequences/:id
DELETE /api/v1/productions/:production_id/sequences/:id

GET    /api/v1/productions/:production_id/sequences/:sequence_id/scenes
# ...and similar patterns for nested scenes, action_beats, and shots
```

All endpoints require authentication and proper permissions to access.