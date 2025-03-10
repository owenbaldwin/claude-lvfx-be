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
- Added `type` field with 'action'/'dialogue' enum
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

## 3. Controller Updates

Updated all controllers to support the new model structure:
- Added proper relation handling
- Updated strong parameters to include new fields
- Maintained RESTful API design
- Ensured proper authentication and authorization
- Added error handling

## 4. Testing

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

The update maintains the existing nested RESTful routes structure:

```
GET    /api/v1/productions/:production_id/scripts/:script_id/sequences
POST   /api/v1/productions/:production_id/scripts/:script_id/sequences
GET    /api/v1/productions/:production_id/scripts/:script_id/sequences/:id
PUT    /api/v1/productions/:production_id/scripts/:script_id/sequences/:id
DELETE /api/v1/productions/:production_id/scripts/:script_id/sequences/:id

# ...and similar patterns for scenes, action_beats, and shots
```

All endpoints require authentication and proper permissions to access.