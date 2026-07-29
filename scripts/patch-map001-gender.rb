#!/usr/bin/env ruby
# frozen_string_literal: true
# Fix TGOM intro gender Show Picture positions (male was x=-180, off-screen).
# Safe to re-run. Usage: patch-map001-gender.rb path/to/Map001.rxdata

path = ARGV[0] or abort "usage: #{$0} Map001.rxdata"
abort "missing #{path}" unless File.file?(path)

class Table
  def self._load(data)
    obj = allocate
    obj.instance_variable_set(:@raw, data)
    obj
  end
  def _dump(_ = 0)
    @raw
  end
end
class Color
  def self._load(data); allocate.tap { |o| o.instance_variable_set(:@raw, data) }; end
  def _dump(_ = 0); @raw; end
end
class Tone
  def self._load(data); allocate.tap { |o| o.instance_variable_set(:@raw, data) }; end
  def _dump(_ = 0); @raw; end
end
module RPG
  class Map
    attr_accessor :tileset_id, :width, :height, :autoplay_bgm, :bgm,
                  :autoplay_bgs, :bgs, :encounter_list, :encounter_step,
                  :data, :events
  end
  class Event
    attr_accessor :id, :name, :x, :y, :pages
    class Page
      attr_accessor :condition, :graphic, :move_type, :move_speed, :move_frequency,
                    :move_route, :walk_anime, :step_anime, :direction_fix, :through,
                    :always_on_top, :trigger, :list
      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid,
                      :switch1_id, :switch2_id, :variable_id, :variable_value, :self_switch_ch
      end
      class Graphic
        attr_accessor :tile_id, :character_name, :character_hue, :direction, :pattern,
                      :opacity, :blend_type
      end
    end
  end
  class MoveRoute; attr_accessor :repeat, :skippable, :list; end
  class MoveCommand; attr_accessor :code, :parameters; end
  class EventCommand; attr_accessor :code, :indent, :parameters; end
  class AudioFile; attr_accessor :name, :volume, :pitch; end
end

map = Marshal.load(File.binread(path))
ev = map.events && map.events[1]
unless ev
  warn "patch-map001: no event #1 — skip"
  exit 0
end

changed = 0
ev.pages[0].list.each do |c|
  next unless c.respond_to?(:code)
  if c.code == 231 && c.parameters[1].to_s == "trainer000"
    if c.parameters[4].to_i < 0 || c.parameters[4].to_i == 176
      c.parameters[4] = 176
      c.parameters[5] = 200
      changed += 1
    end
  elsif c.code == 231 && c.parameters[1].to_s == "trainer001"
    if c.parameters[4].to_i <= 200
      c.parameters[4] = 336
      c.parameters[5] = 200
      changed += 1
    end
  elsif c.code == 232 && [5, 6].include?(c.parameters[0].to_i)
    if c.parameters[4].to_i == 0 && c.parameters[5].to_i == 0
      c.parameters[2] = 1
      c.parameters[4] = 256
      c.parameters[5] = 200
      changed += 1
    end
  end
end

if changed > 0
  File.write(path, Marshal.dump(map))
  puts "  + Map001 gender pictures updated (#{changed} cmds)"
else
  puts "  · Map001 gender pictures already OK"
end
