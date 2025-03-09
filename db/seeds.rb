# db/seeds.rb

# Clear existing data
Shot.destroy_all
ActionBeat.destroy_all
Scene.destroy_all
Sequence.destroy_all
Script.destroy_all
ProductionUser.destroy_all
Production.destroy_all
User.destroy_all

# Create admin user
admin = User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Admin',
  last_name: 'User',
  admin: true
)

# Create regular user
user = User.create!(
  email: 'user@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Test',
  last_name: 'User',
  admin: false
)

# Create production
production = Production.create!(
  title: 'The Matrix Reloaded',
  description: 'Neo and the rebels fight against the machines in the Matrix.',
  start_date: Date.today,
  end_date: Date.today + 6.months,
  status: 'pre-production'
)

# Add users to production
ProductionUser.create!(user: admin, production: production, role: 'producer')
ProductionUser.create!(user: user, production: production, role: 'director')

# Create script
script = Script.create!(
  production: production,
  title: 'The Matrix Reloaded',
  description: 'Final shooting script',
  version: 'v1.0',
  date: Date.today
)

# Create sequences
sequence1 = Sequence.create!(
  script: script,
  number: 1,
  name: 'Opening',
  description: 'Neo discovers his powers'
)

sequence2 = Sequence.create!(
  script: script,
  number: 2,
  name: 'Confrontation',
  description: 'Neo confronts Agent Smith'
)

# Create scenes
scene1 = Scene.create!(
  sequence: sequence1,
  number: 1,
  name: 'Awakening',
  description: 'Neo wakes up in his apartment',
  setting: 'Neo\'s Apartment',
  time_of_day: 'Morning'
)

scene2 = Scene.create!(
  sequence: sequence1,
  number: 2,
  name: 'Phone Call',
  description: 'Neo receives a call from Morpheus',
  setting: 'Neo\'s Apartment',
  time_of_day: 'Morning'
)

scene3 = Scene.create!(
  sequence: sequence2,
  number: 3,
  name: 'The Chase',
  description: 'Neo is chased by agents',
  setting: 'City Streets',
  time_of_day: 'Night'
)

# Create action beats
action_beat1 = ActionBeat.create!(
  scene: scene1,
  description: 'Neo sits up in bed suddenly',
  order_number: 1,
  dialogue: '',
  notes: 'Show confusion on his face'
)

action_beat2 = ActionBeat.create!(
  scene: scene1,
  description: 'Neo walks to the window and looks outside',
  order_number: 2,
  dialogue: '',
  notes: 'Slow motion effect as he approaches the window'
)

action_beat3 = ActionBeat.create!(
  scene: scene2,
  description: 'Phone rings, Neo answers',
  order_number: 1,
  dialogue: 'MORPHEUS (V.O.): They\'re coming for you, Neo.',
  notes: 'Phone has a distinctive ring'
)

action_beat4 = ActionBeat.create!(
  scene: scene3,
  description: 'Neo runs down the street, agents in pursuit',
  order_number: 1,
  dialogue: '',
  notes: 'Use drone shots for chase sequence'
)

# Create shots
Shot.create!(
  action_beat: action_beat1,
  number: '1A',
  description: 'Close-up of Neo\'s eyes opening',
  camera_angle: 'Close-up',
  camera_movement: 'Static',
  status: 'planned',
  notes: 'Use special lens for eye detail'
)

Shot.create!(
  action_beat: action_beat1,
  number: '1B',
  description: 'Wide shot of Neo in bed',
  camera_angle: 'Wide',
  camera_movement: 'Static',
  status: 'planned',
  notes: 'Show entire bedroom'
)

Shot.create!(
  action_beat: action_beat2,
  number: '2A',
  description: 'Tracking shot following Neo to window',
  camera_angle: 'Medium',
  camera_movement: 'Tracking',
  status: 'planned',
  notes: 'Slow motion effect'
)

Shot.create!(
  action_beat: action_beat3,
  number: '3A',
  description: 'Close-up of phone ringing',
  camera_angle: 'Close-up',
  camera_movement: 'Static',
  status: 'planned',
  notes: 'Focus on the phone'
)

Shot.create!(
  action_beat: action_beat3,
  number: '3B',
  description: 'Medium shot of Neo answering phone',
  camera_angle: 'Medium',
  camera_movement: 'Static',
  status: 'planned',
  notes: 'Show reaction to voice'
)

Shot.create!(
  action_beat: action_beat4,
  number: '4A',
  description: 'Drone shot of chase scene',
  camera_angle: 'Bird\'s eye',
  camera_movement: 'Drone tracking',
  status: 'planned',
  notes: 'Coordinate with drone team'
)

Shot.create!(
  action_beat: action_beat4,
  number: '4B',
  description: 'Close-up of Neo\'s feet running',
  camera_angle: 'Low angle',
  camera_movement: 'Tracking',
  status: 'planned',
  notes: 'Focus on special boots'
)

puts "Seed data created successfully!"