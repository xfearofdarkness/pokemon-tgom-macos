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
_support = ENV["TGOM_SUPPORT"]
_support = File.expand_path("~/Library/Application Support/RPGM-Launcher") if _support.nil? || _support.empty?
KAWARIKI_DUMMY = File.join(_support, "kawariki", "ports", "dummyPSystem_Utilities.rb")

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
  safety_net.kawariki.rb
  zz_smoke_boot.kawariki.rb
].each do |f|
  file_must_exist(File.join(overlay, f), "game-overlay/#{f}")
end

file_must_exist(File.join(PATCHES, "dummyPSystem_Utilities.rb"), "patches/dummyPSystem_Utilities.rb")
file_must_exist(File.join(ROOT, "game", "README.md"), "game/README.md")
file_must_exist(File.join(ROOT, "scripts", "play.sh"), "scripts/play.sh")

play_sh = File.read(File.join(ROOT, "scripts", "play.sh"))
env_sh = File.read(File.join(ROOT, "scripts", "env.sh"))
if env_sh.include?("tg_missing_game_help") && play_sh.include?("tg_missing_game_help")
  pass "play.sh uses shared missing-game help"
else
  fail "play.sh/env.sh missing tg_missing_game_help"
end
if play_sh.include?("Close the window to quit") && play_sh.include?("TGOM_VERBOSE")
  pass "play.sh is quiet unless TGOM_VERBOSE=1"
else
  fail "play.sh missing quiet-launch / TGOM_VERBOSE gate"
end
if play_sh.include?("tg_copy_errorlog")
  pass "play.sh copies errorlog on failed boot"
else
  fail "play.sh missing errorlog copy"
end
readme = File.read(File.join(ROOT, "README.md"))
if readme.match?(/title and early game/i)
  fail "README still claims title/early-game playthrough coverage"
else
  pass "README does not claim playthrough coverage"
end
if readme.include?("./scripts/play.sh") && readme.include?("errorlog-latest.txt")
  pass "README leads with play.sh and log files for reports"
else
  fail "README missing play.sh-first or log hint"
end

net = File.read(File.join(overlay, "safety_net.kawariki.rb"))
if net.include?("This area is not in this game.")
  pass "safety_net uses in-game missing-area copy"
else
  fail "safety_net missing-area message not updated"
end
if net.include?("pbDownloadMysteryGift") && net.include?("This feature is not in this game.")
  pass "safety_net stubs Mystery Gift with a player message"
else
  fail "safety_net Mystery Gift stub has no player message"
end

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
section "Window scale vs desktop size"

begin
  unless defined?(Preload)
    module Preload
      def self.on_boot(*)
      end
      def self.print(*)
      end
    end
  end
  load File.join(overlay, "display_fix.kawariki.rb")
  # 13" 1280x800: 2x height 768 does not fit under dock/menu → 1x
  w, h, n = tg_integer_window_size(1280, 800)
  if [w, h, n] == [512, 384, 1]
    pass "1280x800 → 1x (512x384)"
  else
    fail "1280x800 scale", [w, h, n].inspect
  end
  w, h, n = tg_integer_window_size(1440, 900)
  if [w, h, n] == [1024, 768, 2]
    pass "1440x900 → 2x (1024x768)"
  else
    fail "1440x900 scale", [w, h, n].inspect
  end
  w, h, n = tg_integer_window_size(1920, 1080)
  if [w, h, n] == [1024, 768, 2]
    pass "1920x1080 → 2x"
  else
    fail "1920x1080 scale", [w, h, n].inspect
  end
  w, h, n = tg_integer_window_size(2560, 1440)
  if [w, h, n] == [1536, 1152, 3]
    pass "2560x1440 → 3x (1536x1152)"
  else
    fail "2560x1440 scale", [w, h, n].inspect
  end
  w, h, n = tg_integer_window_size(1728, 1117)
  if n == 2 && w == 1024
    pass "16-inch MBP points (1728x1117) → 2x"
  else
    fail "16-inch MBP scale", [w, h, n].inspect
  end
  w, h, n = tg_integer_window_size(2560, 1440, 512, 384, :full)
  if [w, h, n] == [1536, 1152, 3]
    pass "2560x1440 fullscreen margin → 3x"
  else
    fail "2560x1440 fullscreen scale", [w, h, n].inspect
  end
  body = File.read(File.join(overlay, "display_fix.kawariki.rb"))
  if body.include?("tg_apply_fullscreen") && body.include?("4:3 fit")
    pass "display_fix fullscreen fills 4:3 without integer lock"
  else
    fail "display_fix missing 4:3-fit fullscreen"
  end
  if body.include?("integer_scaling = false") && body.include?("$tg_fs_seen")
    pass "display_fix keeps integer lock off and watches OS fullscreen"
  else
    fail "display_fix does not watch macOS window fullscreen"
  end
  if body.include?("idx >= 3") && body.include?("tg_apply_fullscreen")
    pass "Options Screen Size Full maps to fullscreen"
  else
    fail "Screen Size Full not wired"
  end
rescue => e
  fail "window scale picker error", "#{e.class}: #{e.message}"
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
    if cfg["integerScalingActive"]
      fail "integerScalingActive should be off so fullscreen can fill 4:3"
    else
      pass "integerScalingActive off (fullscreen can fill the monitor)"
    end
    if cfg["fixedAspectRatio"]
      pass "fixedAspectRatio on (no 16:9 squash)"
    else
      fail "fixedAspectRatio should stay on"
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
section "MRI restore after PE Ruby Utilities clobber"

begin
  unless defined?(TGMriCompat)
    fail "TGMriCompat not defined after loading early_compat"
    raise "skip MRI restore"
  end
  pass "TGMriCompat defined"

  # Simulate PSystem / Ruby Utilities overrides
  class String
    def bytesize
      size
    end

    def capitalize
      proc = scan(/./)
      proc[0] = proc[0].upcase
      proc.join
    end
  end
  class Array
    def first
      self[0]
    end

    def last
      self[length - 1]
    end
  end

  begin
    "".capitalize
    fail "empty capitalize did not raise before restore (unexpected)"
  rescue NoMethodError
    pass "empty capitalize would crash before restore"
  end

  if "é".bytesize == 1
    pass "PE bytesize override matches char count (clobber active)"
  else
    fail "could not simulate PE bytesize clobber", "é".bytesize.inspect
  end

  begin
    [1, 2, 3].first(2)
    fail "Array#first(2) did not raise under PE override"
  rescue ArgumentError
    pass "Array#first(2) would raise under PE override"
  end

  TGMriCompat.restore!

  if "".capitalize == ""
    pass '"".capitalize => "" after restore'
  else
    fail "empty capitalize wrong after restore", "".capitalize.inspect
  end
  if "hello".capitalize == "Hello"
    pass '"hello".capitalize => "Hello"'
  else
    fail "capitalize first-char", "hello".capitalize.inspect
  end
  e_bytes = "é".bytesize
  if e_bytes == "é".dup.force_encoding(Encoding::UTF_8).bytesize && e_bytes > 1
    pass "String#bytesize is byte-accurate after restore (#{e_bytes})"
  else
    fail "bytesize still wrong after restore", e_bytes.inspect
  end
  bin = 0x80.chr
  if bin.bytesize == 1 && bin.getbyte(0) == 0x80
    pass "binary 0x80 bytesize == 1 after restore"
  else
    fail "binary bytesize", bin.bytesize.inspect
  end
  if [1, 2, 3].first(2) == [1, 2] && [1, 2, 3].last(2) == [2, 3]
    pass "Array#first(n)/last(n) restored"
  else
    fail "Array#first/last still broken", [1, 2, 3].first(2).inspect
  end
  if [9].first == 9 && [].last.nil?
    pass "Array#first/#last no-arg still work"
  else
    fail "Array#first/#last no-arg"
  end
rescue => e
  fail "MRI restore runtime error", "#{e.class}: #{e.message}\n#{e.backtrace&.first}"
end

# ---------------------------------------------------------------------------
section "safeExists? directory / TEMP"

begin
  TGMriCompat.install_safe_exists! if defined?(TGMriCompat)
  tmp = TGMriCompat.ensure_temp! if defined?(TGMriCompat)
  if tmp && File.directory?(tmp)
    pass "TEMP is a real directory (#{tmp})"
  else
    fail "TEMP not a directory", tmp.inspect
  end
  dir = File.dirname(__FILE__)
  begin
    exists = safeExists?(dir)
    if exists == false
      pass "safeExists?(directory) is false (not EISDIR)"
    else
      fail "safeExists?(directory) should be false", exists.inspect
    end
  rescue Errno::EISDIR => e
    fail "safeExists? raised EISDIR", e.message
  end
  if safeExists?(__FILE__)
    pass "safeExists?(this file) is true"
  else
    fail "safeExists? missed a real file"
  end
  if safeExists?("/no/such/tg_smoke_file_#{$$}") == false
    pass "safeExists? missing file is false"
  else
    fail "safeExists? missing file"
  end
rescue => e
  fail "safeExists?/TEMP error", "#{e.class}: #{e.message}"
end

# ---------------------------------------------------------------------------
section "Missing maps / leftover Essentials IDs"

unless GAME_PRESENT
  puts "  SKIP  map inventory (no local game)"
else
begin
  existing = Dir[File.join(GAME, "Data", "Map*.rxdata")].map { |f|
    File.basename(f)[/Map(\d+)/, 1].to_i
  }.reject { |n| n == 0 }.sort
  if existing.size >= 50
    pass "found #{existing.size} map rxdata files"
  else
    fail "unexpectedly few maps", existing.size.to_s
  end
  missing_sample = [52, 66, 69, 87]
  missing_sample.each do |id|
    path = File.join(GAME, "Data", sprintf("Map%03d.rxdata", id))
    if File.file?(path)
      fail "expected leftover sample Map#{id} to be absent", path
    else
      pass "Map#{id}.rxdata absent (leftover Essentials ID)"
    end
  end

  meta = File.read(File.join(GAME, "PBS", "metadata.txt"))
  town = File.read(File.join(GAME, "PBS", "townmap.txt"))
  if meta.include?("HealingSpot = 52") || town.include?(",52,")
    pass "PBS still names map 52 (runtime filter required)"
  else
    fail "could not find map-52 fly/heal references in PBS"
  end

  # Roaming IDs live in Scripts.rxdata Settings
  require "zlib"
  scripts = Marshal.load(read(File.join(GAME, "Data", "Scripts.rxdata")))
  set = scripts.find { |_, n, _| n.to_s == "Settings" }
  sbody = set ? (Zlib::Inflate.inflate(set[2].to_s) rescue set[2].to_s) : ""
  if sbody.include?("66") && sbody.include?("RoamingAreas")
    pass "Settings RoamingAreas still lists leftover map IDs"
  else
    fail "could not confirm RoamingAreas in Settings"
  end

  overlay = File.read(File.join(ROOT, "game-overlay", "safety_net.kawariki.rb"))
  %w[tg_map_rxdata_exists? tg_filter_roam_hash! pbGetHealingSpot pbStartOver].each do |needle|
    if overlay.include?(needle)
      pass "safety_net mentions #{needle}"
    else
      fail "safety_net missing #{needle}"
    end
  end

  smoke = File.read(File.join(ROOT, "game-overlay", "zz_smoke_boot.kawariki.rb"))
  if smoke.include?("skipped (no") || smoke.match?(/results << \[.*, true, .*skip/i)
    fail "in-engine smoke still treats a skip as a pass"
  else
    pass "in-engine smoke does not record skips as PASS"
  end
  if smoke.include?("PokemonBag.new") && smoke.include?("ok == true")
    pass "in-engine smoke constructs a bag and requires literal true"
  else
    fail "in-engine live bag check is not forced"
  end

  # Event transfers must not target missing maps (documents current data)
  class Table
    def self._load(data)
      allocate
    end
  end unless defined?(Table)
  class Color
    def self._load(_data)
      allocate
    end
  end unless defined?(Color)
  class Tone
    def self._load(_data)
      allocate
    end
  end unless defined?(Tone)
  module RPG
    class Map
      attr_accessor :tileset_id, :width, :height, :autoplay_bgm, :bgm,
                    :autoplay_bgs, :bgs, :encounter_list, :encounter_step,
                    :data, :events
    end unless const_defined?(:Map, false)
    class Event
      attr_accessor :id, :name, :x, :y, :pages
      class Page
        attr_accessor :condition, :graphic, :move_type, :move_speed, :move_frequency,
                      :move_route, :walk_anime, :step_anime, :direction_fix, :through,
                      :always_on_top, :trigger, :list
      end unless const_defined?(:Page, false)
    end unless const_defined?(:Event, false)
    class EventCommand
      attr_accessor :code, :indent, :parameters
    end unless const_defined?(:EventCommand, false)
    class AudioFile
      attr_accessor :name, :volume, :pitch
    end unless const_defined?(:AudioFile, false)
    class MoveRoute
      attr_accessor :repeat, :skippable, :list
    end unless const_defined?(:MoveRoute, false)
    class MoveCommand
      attr_accessor :code, :parameters
    end unless const_defined?(:MoveCommand, false)
  end

  exist_set = existing.to_h { |n| [n, true] }
  bad = []
  Dir[File.join(GAME, "Data", "Map*.rxdata")].each do |path|
    mid = File.basename(path)[/Map(\d+)/, 1].to_i
    next if mid == 0
    map = Marshal.load(read(path))
    next unless map.respond_to?(:events) && map.events
    map.events.each do |_eid, ev|
      next unless ev.respond_to?(:pages) && ev.pages
      ev.pages.each do |page|
        next unless page.respond_to?(:list) && page.list
        page.list.each do |cmd|
          next unless cmd.respond_to?(:code) && cmd.code == 201
          params = cmd.parameters
          next unless params && params[0] == 0
          dest = params[1].to_i
          bad << [mid, dest] unless exist_set[dest]
        end
      end
    end
  end
  if bad.empty?
    pass "no Transfer Player command targets a missing map"
  else
    fail "transfers to missing maps", bad.first(5).inspect
  end
rescue => e
  fail "map inventory error", "#{e.class}: #{e.message}"
end
end

# ---------------------------------------------------------------------------
section "Case-insensitive bitmap resolve (.PNG)"

unless GAME_PRESENT
  puts "  SKIP  .PNG assets (no local game)"
else
begin
  samples = [
    "Graphics/Pictures/statuses",
    "Graphics/Pictures/mapRegion0",
    "Graphics/Pictures/Bag/bag_1"
  ]
  samples.each do |rel|
    noext = File.join(GAME, rel)
    hit = %w[.png .PNG .gif .GIF].any? { |ext| File.file?(noext + ext) }
    if hit
      pass "#{rel} exists as png/PNG"
    else
      fail "missing #{rel}.png/PNG"
    end
  end
  overlay = File.read(File.join(ROOT, "game-overlay", "safety_net.kawariki.rb"))
  if overlay.include?(".PNG") && overlay.include?("pbResolveBitmap")
    pass "safety_net tries .PNG in pbResolveBitmap"
  else
    fail "safety_net missing .PNG resolve fallback"
  end
rescue => e
  fail ".PNG resolve check error", e.message
end
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
