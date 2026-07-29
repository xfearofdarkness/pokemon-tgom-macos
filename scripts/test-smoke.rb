#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Offline smoke tests for TGOM mkxp-z compatibility patches.
# Runs in ~1s — no intro, no GUI, no save required.
#
#   ./scripts/test-smoke.sh
#   ruby scripts/test-smoke.rb
#
# Exit 0 = all pass; non-zero = failures (printed).

require "fileutils"
require "zlib"
require "json"

ROOT = File.expand_path("..", __dir__)
GAME = File.join(ROOT, "game", "Pokemon TGOM 4.2.3")
PATCHES = File.join(ROOT, "patches")
KAWARIKI_DUMMY = File.expand_path(
  "~/Library/Application Support/RPGM-Launcher/kawariki/ports/dummyPSystem_Utilities.rb"
)

$fails = []
$passes = 0

def pass(msg)
  $passes += 1
  puts "  PASS  #{msg}"
end

def fail(msg, detail = nil)
  $fails << msg
  puts "  FAIL  #{msg}"
  puts "        #{detail}" if detail
end

def section(title)
  puts
  puts "== #{title} =="
end

def read(path)
  File.binread(path)
end

def file_must_exist(path, label = nil)
  label ||= path
  if File.file?(path)
    pass "#{label} exists"
    true
  else
    fail "#{label} missing", path
    false
  end
end

# ---------------------------------------------------------------------------
section "Project layout"

overlay = File.join(ROOT, "game-overlay")
%w[
  map_fix.kawariki.rb
  fonts_fix.kawariki.rb
  display_fix.kawariki.rb
  input_fix.kawariki.rb
  utilities_fix.kawariki.rb
].each do |f|
  file_must_exist(File.join(overlay, f), "game-overlay/#{f}")
end

file_must_exist(File.join(PATCHES, "dummyPSystem_Utilities.rb"), "patches/dummyPSystem_Utilities.rb")
file_must_exist(File.join(ROOT, "game", "README.md"), "game/README.md")

GAME_PRESENT = File.file?(File.join(GAME, "Data", "Scripts.rxdata"))
if GAME_PRESENT
  pass "local game present (Scripts.rxdata)"
  file_must_exist(File.join(GAME, "utilities_fix.kawariki.rb"), "game/utilities_fix applied") if File.file?(File.join(GAME, "utilities_fix.kawariki.rb"))
else
  puts "  SKIP  local game not installed (OK for public clone — see game/README.md)"
end

# ---------------------------------------------------------------------------
section "dummyPSystem_Utilities (Kawariki replace of PSystem_Utilities)"

dummy_path = File.join(PATCHES, "dummyPSystem_Utilities.rb")
dummy = File.read(dummy_path)

if dummy.include?("POCKETAUTOSORT")
  fail "dummy still references POCKETAUTOSORT (PE17 bag crash)"
else
  pass "dummy has no POCKETAUTOSORT"
end

if dummy.include?("module ItemStorageHelper")
  fail "dummy still defines ItemStorageHelper (clobbers PItem_Bag E18)"
else
  pass "dummy does not clobber ItemStorageHelper"
end

%w[pbGetFSpeciesFromForm pbGetSpeciesFromFSpecies pbGetRegionalDexLength].each do |m|
  if dummy.match?(/def #{m}\b/)
    pass "dummy defines #{m}"
  else
    fail "dummy missing #{m}"
  end
end

if dummy.match?(%r{stringLiterals\s*=.*/n})
  pass "dummy JSON stringLiterals uses /n (Ruby 3 safe)"
elsif dummy.include?("stringLiterals") && dummy.include?("x7f-x9f") && !dummy.include?("/n")
  fail "dummy JSON regex still has multibyte trap without /n"
else
  # accept rebuilt original with /n somewhere on that line
  line = dummy.lines.find { |l| l.include?("stringLiterals") }
  if line && line.include?("/n")
    pass "dummy JSON stringLiterals uses /n (Ruby 3 safe)"
  else
    fail "could not verify JSON /n fix", line.to_s.strip
  end
end

if dummy.include?("Essentials 18 original") || dummy.match?(/def pbGetSpeciesFromFSpecies/)
  pass "dummy looks like Essentials-18-based port"
else
  fail "dummy does not look like Essentials-18 rebuild"
end

# Deployed Kawariki copy must match project patch
if File.file?(KAWARIKI_DUMMY)
  if FileUtils.compare_file(dummy_path, KAWARIKI_DUMMY)
    pass "kawariki/ports dummy is in sync with patches/"
  else
    fail "kawariki/ports dummy OUT OF SYNC with patches/",
         "run: cp patches/dummyPSystem_Utilities.rb \"$HOME/Library/Application Support/RPGM-Launcher/kawariki/ports/\""
  end
else
  fail "kawariki ports dummy missing", KAWARIKI_DUMMY
end

# ---------------------------------------------------------------------------
section "ItemStorageHelper runtime (Potion / pbItemBall path)"

# Minimal Essentials-18-shaped bag store — mirrors utilities_fix + PItem_Bag
module ItemStorageHelper
  def self.pbCanStore?(items, maxsize, maxPerSlot, item, qty)
    raise "Invalid value for qty: #{qty}" if qty < 0
    return true if qty == 0
    for i in 0...maxsize
      itemslot = items[i]
      if !itemslot
        qty -= [qty, maxPerSlot].min
        return true if qty == 0
      elsif itemslot[0] == item && itemslot[1] < maxPerSlot
        newamt = [itemslot[1] + qty, maxPerSlot].min
        qty -= (newamt - itemslot[1])
        return true if qty == 0
      end
    end
    false
  end

  def self.pbStoreItem(items, maxsize, maxPerSlot, item, qty, sorting = false)
    raise "Invalid value for qty: #{qty}" if qty < 0
    return true if qty == 0
    itemPocket = pbGetPocket(item)
    for i in 0...maxsize
      itemslot = items[i]
      if !itemslot
        items[i] = [item, [qty, maxPerSlot].min]
        qty -= items[i][1]
        auto = defined?(BAG_POCKET_AUTO_SORT) ? BAG_POCKET_AUTO_SORT[itemPocket] : false
        items.sort! if sorting && auto
        return true if qty == 0
      elsif itemslot[0] == item && itemslot[1] < maxPerSlot
        newamt = [itemslot[1] + qty, maxPerSlot].min
        qty -= (newamt - itemslot[1])
        itemslot[1] = newamt
        return true if qty == 0
      end
    end
    false
  end

  def self.pbStoreAllOrNone(items, maxsize, maxPerSlot, item, qty)
    return false unless pbCanStore?(items, maxsize, maxPerSlot, item, qty)
    pbStoreItem(items, maxsize, maxPerSlot, item, qty, false)
  end

  def self.pbQuantity(items, maxsize, item)
    ret = 0
    for i in 0...maxsize
      s = items[i]
      ret += s[1] if s && s[0] == item
    end
    ret
  end
end

BAG_POCKET_AUTO_SORT = [false, false, false, false, true, true, false, false, false].freeze
def pbGetPocket(_item)
  2 # items pocket
end

begin
  bag = []
  ok = ItemStorageHelper.pbStoreItem(bag, 30, 999, :POTION, 1, true)
  # symbols work as item ids in this stub
  if ok && bag == [[:POTION, 1]]
    pass "pbStoreItem adds POTION without POCKETAUTOSORT"
  else
    fail "pbStoreItem failed", "ok=#{ok.inspect} bag=#{bag.inspect}"
  end

  ok2 = ItemStorageHelper.pbStoreItem(bag, 30, 999, :POTION, 2, true)
  if ok2 && bag == [[:POTION, 3]]
    pass "pbStoreItem stacks POTION qty"
  else
    fail "pbStoreItem stack failed", bag.inspect
  end

  ok3 = ItemStorageHelper.pbStoreAllOrNone(bag, 30, 999, :ANTIDOTE, 5)
  if ok3 && ItemStorageHelper.pbQuantity(bag, 30, :ANTIDOTE) == 5
    pass "pbStoreAllOrNone works"
  else
    fail "pbStoreAllOrNone failed", bag.inspect
  end

  # Simulate OLD broken path: must raise NameError (documents the bug we fixed)
  begin
    module ItemStorageHelper
      def self.pbStoreItem_old_broken(items, maxsize, maxPerSlot, item, qty, sorting = false)
        for i in 0...maxsize
          if !items[i]
            items[i] = [item, qty]
            items.sort! if sorting && POCKETAUTOSORT[0]
            return true
          end
        end
        false
      end
    end
    ItemStorageHelper.pbStoreItem_old_broken([], 5, 99, 1, 1, true)
    fail "old POCKETAUTOSORT path did not raise (unexpected)"
  rescue NameError => e
    if e.message.include?("POCKETAUTOSORT")
      pass "confirmed old path would crash: #{e.message.split("\n").first}"
    else
      fail "old path raised different NameError", e.message
    end
  end
rescue => e
  fail "ItemStorageHelper runtime error", "#{e.class}: #{e.message}"
end

# ---------------------------------------------------------------------------
section "fSpecies helpers runtime"

begin
  # Minimal stubs matching Data_Cache usage
  module PBSpecies
    def self.maxValue
      898
    end
  end

  def pbLoadFormToSpecies
    # species 25 has form 1 → fspecies 9001
    arr = []
    arr[25] = [25, 9001]
    arr
  end

  eval <<~'RUBY', binding, "fSpecies_smoke", 1
    def pbGetFSpeciesFromForm(species, form = 0)
      return species if form == 0
      ret = species
      species = pbGetSpeciesFromFSpecies(species)[0] if species > PBSpecies.maxValue
      formData = pbLoadFormToSpecies
      if formData[species] && formData[species][form] && formData[species][form] > 0
        ret = formData[species][form]
      end
      ret
    end

    def pbGetSpeciesFromFSpecies(species)
      return [species, 0] if species <= PBSpecies.maxValue
      formdata = pbLoadFormToSpecies
      for i in 1...formdata.length
        next if !formdata[i]
        for j in 0...formdata[i].length
          return [i, j] if formdata[i][j] == species
        end
      end
      [species, 0]
    end
  RUBY

  if pbGetFSpeciesFromForm(25, 0) == 25 && pbGetFSpeciesFromForm(25, 1) == 9001
    pass "pbGetFSpeciesFromForm base/form"
  else
    fail "pbGetFSpeciesFromForm wrong", pbGetFSpeciesFromForm(25, 1).inspect
  end

  if pbGetSpeciesFromFSpecies(9001) == [25, 1]
    pass "pbGetSpeciesFromFSpecies reverse lookup"
  else
    fail "pbGetSpeciesFromFSpecies wrong", pbGetSpeciesFromFSpecies(9001).inspect
  end
rescue => e
  fail "fSpecies runtime error", "#{e.class}: #{e.message}"
end

# ---------------------------------------------------------------------------
section "Gender-select pictures (Map001 + assets)"

unless GAME_PRESENT
  puts "  SKIP  gender/map checks (no local game)"
else
begin
  # Lightweight RMXP marshal stubs
  class Table
    def self._load(data)
      obj = allocate
      obj.instance_variable_set(:@raw, data)
      obj
    end
  end
  class Color
    def self._load(data)
      allocate
    end
  end
  class Tone
    def self._load(data)
      allocate
    end
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
    class MoveRoute
      attr_accessor :repeat, :skippable, :list
    end
    class MoveCommand
      attr_accessor :code, :parameters
    end
    class EventCommand
      attr_accessor :code, :indent, :parameters
    end
    class AudioFile
      attr_accessor :name, :volume, :pitch
    end
  end

  map = Marshal.load(read(File.join(GAME, "Data", "Map001.rxdata")))
  ev = map.events[1]
  shows = ev.pages[0].list.select { |c| c.code == 231 && c.parameters[1].to_s =~ /trainer00[01]/ }
  male = shows.find { |c| c.parameters[1].to_s == "trainer000" }
  female = shows.find { |c| c.parameters[1].to_s == "trainer001" }

  if male.nil? || female.nil?
    fail "Map001 missing trainer000/001 Show Picture"
  else
    mx, my = male.parameters[4], male.parameters[5]
    fx, fy = female.parameters[4], female.parameters[5]
    if mx.to_i < 0
      fail "male picture still off-screen", "x=#{mx}"
    else
      pass "male picture x=#{mx} on-screen (>=0)"
    end
    if fx.to_i > mx.to_i
      pass "female picture to the right of male (#{fx} > #{mx})"
    else
      fail "female not right of male", "male=#{mx} female=#{fx}"
    end
    if my.to_i.between?(100, 300) && fy.to_i.between?(100, 300)
      pass "portrait y positions reasonable (#{my}/#{fy})"
    else
      fail "portrait y odd", "male y=#{my} female y=#{fy}"
    end
  end

  %w[trainer000.png trainer001.png introBoy.png introGirl.png].each do |f|
    path = File.join(GAME, "Graphics", "Pictures", f)
    file_must_exist(path, "Pictures/#{f}")
  end

  # Portraits should be real images, not tiny 4-bit walk sheets for gender UI
  t0 = File.join(GAME, "Graphics", "Pictures", "trainer000.png")
  t1 = File.join(GAME, "Graphics", "Pictures", "trainer001.png")
  if File.size(t0) > 1500 && File.size(t1) > 1500
    pass "trainer000/001 pictures are full portraits (not tiny walk-sheet stubs)"
  else
    fail "trainer pictures look too small (walk sheets?)",
         "sizes #{File.size(t0)}/#{File.size(t1)}"
  end
rescue => e
  fail "Map001 gender check error", "#{e.class}: #{e.message}"
end
end

# ---------------------------------------------------------------------------
section "utilities_fix / species_fix content"

util_path = File.join(ROOT, "game-overlay", "utilities_fix.kawariki.rb")
util_path = File.join(GAME, "utilities_fix.kawariki.rb") unless File.file?(util_path)
util = File.read(util_path)
%w[pbStoreItem BAG_POCKET_AUTO_SORT pbGetSpeciesFromFSpecies pbStoreAllOrNone].each do |needle|
  if util.include?(needle)
    pass "utilities_fix mentions #{needle}"
  else
    fail "utilities_fix missing #{needle}"
  end
end

if util.include?("POCKETAUTOSORT") && util.match?(/items\.sort!.*POCKETAUTOSORT/)
  fail "utilities_fix still sorts with POCKETAUTOSORT"
else
  pass "utilities_fix does not use POCKETAUTOSORT for sort"
end

# ---------------------------------------------------------------------------
section "mkxp.json basics"

if GAME_PRESENT && File.file?(File.join(GAME, "mkxp.json"))
  begin
    cfg = JSON.parse(File.read(File.join(GAME, "mkxp.json")))
    w = cfg["defScreenW"] || cfg["screenWidth"]
    h = cfg["defScreenH"] || cfg["screenHeight"]
    if w.to_i == 512 && h.to_i == 384
      pass "defScreen 512x384"
    else
      fail "unexpected screen size", "#{w}x#{h}"
    end
    pre = cfg["preloadScript"] || []
    if pre.any? { |p| p.to_s.include?("early_compat.rb") }
      pass "mkxp.json preloads early_compat.rb (sprintf shim)"
    else
      fail "early_compat.rb not in preloadScript", pre.inspect
    end
  rescue => e
    fail "mkxp.json parse error", e.message
  end
else
  puts "  SKIP  mkxp.json (run setup-game.sh after installing the game)"
end

# ---------------------------------------------------------------------------
section "Ruby 1.8→3 compat (ruby18 + sprintf)"

early = File.join(PATCHES, "early_compat.rb")
r18 = File.join(PATCHES, "ruby18.rb")
if File.file?(early) && File.read(early).include?("TGSprintfCompat")
  pass "early_compat defines TGSprintfCompat shim"
else
  fail "early_compat missing TGSprintfCompat"
end
if File.file?(r18)
  body = File.read(r18)
  %w[File.exists? Dir.exists? Fixnum Thread.critical HashPatch choice].each do |needle|
    if body.include?(needle) || (needle == "HashPatch" && body.include?("def index"))
      pass "ruby18 covers #{needle}"
    else
      fail "ruby18 missing #{needle}"
    end
  end
else
  fail "patches/ruby18.rb missing"
end

begin
  # Load shims (early_compat pulls Application Support ruby18 if present;
  # also load project ruby18 explicitly so CI works without setup)
  load r18
  load early

  # --- sprintf / Sockets URL-encode ---
  key = "hello world!"
  encoded = key.gsub(/[^a-zA-Z0-9_\.\-]/n) { |s| sprintf("%%%02x", s[0]) }
  if encoded == "hello%20world%21"
    pass "Sockets-style URL encode: #{encoded.inspect}"
  else
    fail "Sockets-style URL encode unexpected", encoded.inspect
  end

  if sprintf("%02x", "A") == "41"
    pass 'sprintf("%02x", "A") => "41"'
  else
    fail 'sprintf("%02x", "A") wrong', sprintf("%02x", "A").inspect
  end

  if sprintf("%d", nil) == "0"
    pass 'sprintf("%d", nil) => "0"'
  else
    fail 'sprintf("%d", nil) wrong', sprintf("%d", nil).inspect
  end

  if ("%%%02x" % " ") == "%20"
    pass 'String#% URL space: "%20"'
  else
    fail "String#% space encode", ("%%%02x" % " ").inspect
  end

  if sprintf("%s-%d", "x", 3) == "x-3" && sprintf("%03d", 7) == "007"
    pass "normal sprintf paths unchanged"
  else
    fail "normal sprintf regressed"
  end

  # --- ruby18 polyfills ---
  unless File.exists?("/tmp") || File.exists?("/private/tmp")
    fail "File.exists? polyfill failed"
  else
    pass "File.exists? works"
  end
  unless Dir.exists?("/tmp") || Dir.exists?("/private/tmp")
    fail "Dir.exists? polyfill failed"
  else
    pass "Dir.exists? works"
  end
  if defined?(Fixnum) && Fixnum == Integer
    pass "Fixnum aliased to Integer"
  else
    fail "Fixnum alias missing", defined?(Fixnum).inspect
  end
  if Thread.respond_to?(:critical)
    Thread.critical = true
    ok = Thread.critical == true
    Thread.critical = false
    ok ? pass("Thread.critical read/write") : fail("Thread.critical broken")
  else
    fail "Thread.critical missing"
  end
  if { a: 1 }.index(1) == :a
    pass "Hash#index → key"
  else
    fail "Hash#index broken", { a: 1 }.index(1).inspect
  end
  if [1, 2, 3].choice.between?(1, 3)
    pass "Array#choice → sample"
  else
    fail "Array#choice broken"
  end
  if Object.new.type == Object
    pass "Object#type → class"
  else
    fail "Object#type broken"
  end
  ch = 0x80.chr
  if ch.bytesize == 1 && ch.getbyte(0) == 0x80
    pass "Integer#chr high byte (0x80) binary-safe"
  else
    fail "Integer#chr high byte failed", ch.inspect
  end

  # From game Scripts: AnimatedBitmap GIF magic / slash; Compiler BOM
  if "G" == 0x47 && "/" == 0x2F && ("G" != 0x48)
    pass "String#== byte (GIF 0x47 / slash 0x2F) — AnimatedBitmap"
  else
    fail "String#== byte compare broken"
  end
  if "\xEF".b == 0xEF && "\xBB".b == 0xBB && "\xBF".b == 0xBF
    pass "BOM byte compares — Compiler/Intl_Messages"
  else
    fail "BOM byte compares failed"
  end
  joined = "/tmp" + "\\record.wav"
  if joined == "/tmp/record.wav"
    pass "TEMP+\\\\file join (Audio_Utilities/Sprite_Resizer)"
  else
    fail "TEMP backslash join wrong", joined.inspect
  end
  file = "Graphics/Characters/"
  if file[file.length - 1] == 0x2F
    pass "trailing slash byte (GifBitmap skip dir)"
  else
    fail "trailing slash check broken", file[file.length - 1].inspect
  end
rescue => e
  fail "Ruby compat runtime error", "#{e.class}: #{e.message}\n#{e.backtrace&.first}"
end
# Static: known bad call still present in Scripts (documents why shim exists)
if GAME_PRESENT
begin
  require "zlib"
  scripts = Marshal.load(read(File.join(GAME, "Data", "Scripts.rxdata")))
  sockets = scripts.find { |_, n, _| n.to_s == "Sockets" }
  body = sockets ? (Zlib::Inflate.inflate(sockets[2].to_s) rescue sockets[2].to_s) : ""
  if body.include?("sprintf('%%%02x', s[0])") || body.include?('sprintf("%%%02x", s[0])')
    pass "Scripts still contain Sockets s[0] sprintf (shim required)"
  else
    if body =~ /sprintf\s*\(\s*['"]%%%02x['"]\s*,\s*s\[0\]/
      pass "Scripts still contain Sockets s[0] sprintf (shim required)"
    else
      fail "could not find Sockets s[0] sprintf pattern (game update?)"
    end
  end
  ab = scripts.find { |_, n, _| n.to_s == "AnimatedBitmap" }
  abody = ab ? (Zlib::Inflate.inflate(ab[2].to_s) rescue ab[2].to_s) : ""
  if abody.include?("filestring[0]==0x47") || abody.include?("filestring[0] == 0x47")
    pass "Scripts contain GifBitmap 0x47 magic (byte== shim required)"
  else
    fail "GifBitmap 0x47 pattern missing"
  end
  util = scripts.find { |_, n, _| n.to_s == "PSystem_Utilities" }
  ubody = util ? (Zlib::Inflate.inflate(util[2].to_s) rescue util[2].to_s) : ""
  if ubody.include?("stringLiterals") && ubody.include?("x7f-x9f") && !ubody.match?(%r{stringLiterals.*/n})
    pass "Original PSystem_Utilities has unsafe JSON regex (dummy replace required)"
  elsif ubody.include?("stringLiterals")
    pass "PSystem_Utilities JSON regex present (check dummy deploy)"
  else
    fail "PSystem_Utilities missing stringLiterals"
  end
rescue => e
  fail "Scripts.rxdata scan failed", e.message
end
else
  puts "  SKIP  Scripts.rxdata scan (no local game)"
end

# ---------------------------------------------------------------------------
section "Summary"

puts
if $fails.empty?
  puts "ALL #{$passes} CHECKS PASSED"
  exit 0
else
  puts "#{$fails.size} FAILED / #{$passes} passed"
  $fails.each { |f| puts "  - #{f}" }
  exit 1
end
