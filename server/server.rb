$: << 'lib'

require 'brains'
require 'redis'

def db
  @db ||= Redis.new
end

# Really bizarre bug where world was getting reset...
$world = World.new(640, 480)
def world; $world end


db.flush_db

10.times do
  world.add(Zombie.new)
end

h = world.add(Human.new_with_brain('http://localhost:4567'))

loop do
  world.update
  world.save
  sleep 1/30.0
end
