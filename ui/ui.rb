require 'gosu'
require 'redis'
require 'json'

def returning(obj)
  yield obj
  obj
end

def db
  @redis ||= Redis.new
end

class ZIndex
  LAYERS = [:world, :dead, :robot, :zombie, :overlay]

  def self.for(type); LAYERS.index(type) end
end

class Actor
  attr_accessor :data

  def self.window=(window); @window = window end
  def self.window; @window end

  def self.sprites
    @sprites ||=  Dir['sprites/*.png'].inject({}) do |sprites,f|
      sprite = File.basename(f,'.*').split('-')
      sprites[sprite.first] ||= {}
      sprites[sprite.first][sprite.last] = Gosu::Image.new(window, f, false)
      sprites
    end
  end

  def self.font
    @font ||= Gosu::Font.new(window, Gosu::default_font_name, 12)
  end

  def self.new_from_string(string)
    returning(new) do |a|
      a.data_from_string(string)
    end
  end

  def data_from_string(string)
    @data = JSON.parse(string)
  end

  def image
    self.class.sprites[data['type']][data['state']]
  end

  def draw
    image.draw_rot(x, y, z, data['dir'])

    if data['type'] == 'robot' && data['state'] == 'attacking'
      x2 = x + Gosu.offset_x(data['dir'], 200)
      y2 = y + Gosu.offset_y(data['dir'], 200)

      window.draw_line(x, y, 0x00FF0000, x2, y2, 0x99FF0000)
    end

    draw_health if robot?
  end

  def font
    self.class.font
  end

  def draw_health
    label = data['name']
    label += " (#{data['health']})" unless dead?

    label_width = font.text_width(label)
    overlay_x = x - label_width /2
    overlay_y = y - 30

    bg_color = 0x33000000

    ldim = {
      :left => overlay_x -2,
      :top => overlay_y -2,
      :right => (x + label_width/2) + 2,
      :bottom => overlay_y + 14
    }

    window.draw_quad(
      ldim[:left], ldim[:top], bg_color,
      ldim[:right], ldim[:top], bg_color,
      ldim[:right], ldim[:bottom], bg_color,
      ldim[:left], ldim[:bottom], bg_color,
      ZIndex.for(:overlay)
    )

    font.draw(label, overlay_x, overlay_y+1, ZIndex.for(:overlay), 1.0, 1.0, 0x99FFFFFF)
    font.draw(label, overlay_x, overlay_y, ZIndex.for(:overlay), 1.0, 1.0, 0xFF000000)
  end

  def x
    data['x']*window.grid
  end

  def y
    window.height - data['y']*window.grid
  end

  def z
    (data['state'] == 'dead') ? ZIndex.for(:dead) : ZIndex.for(data['type'].to_sym)
  end

  def window
    self.class.window
  end

  def robot?
    data['type'] == 'robot'
  end

  def dead?
    data['state'] == 'dead'
  end

  def method_missing(method_name, *args)
    data.has_key?(method_name.to_s) ? data[method_name.to_s] : super
  end
end

class Window < Gosu::Window

  attr_accessor :grid, :actors

  def initialize
    super(640, 480, false)
    self.caption = 'Brains'
    self.grid = 1
    self.actors = []
    Actor.window = self
    @grass = Gosu::Image.new(self, 'tiles/grass.png', true)
    @shrubbery = Gosu::Image.new(self, 'tiles/shrubbery.png', true)
  end

  def update
    actors.clear
    db.keys('*').each do |id|
      if raw = db[id]
        actors << Actor.new_from_string(raw)
      end
    end
  end

  def draw
    draw_scenery
    actors.each {|a| a.draw }
  end

  def button_down(id)
    close if id == Gosu::Button::KbEscape
  end

# private

  def tile_positions
    w, h = @grass.width, @grass.height
    @tile_positions ||= {
      :x => (0...width).to_a.inject([]) {|a,x| a << x if x % w == 0; a},
      :y => (0...height).to_a.inject([]) {|a,y| a << y if y % h == 0; a}
    }
  end

  def map
    @map ||= tile_positions[:y].map do |y|
      tile_positions[:x].map do |x|
        {
          :x => x,
          :y => y,
          :tile => (rand(32) % 32 == 0) ? @shrubbery : @grass
        }
      end
    end
  end

  def draw_scenery
    map.each do |row|
      row.each do |col|
        col[:tile].draw(col[:x], col[:y], ZIndex.for(:world))
      end
    end
  end

end

window = Window.new
window.show