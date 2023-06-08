vasm_sources := $(wildcard src/*.asm)
vasm_objects := $(addprefix obj/, $(patsubst %.asm,%.o,$(notdir $(vasm_sources))))
objects := $(vasm_objects)
deps := $(objects:.o=.d)
data := data/girl-head.BPL data/girl-body.BPL obj/tables_shade1.o data/tex.rgb

program = out/a
OUT = $(program)
CC = m68k-amiga-elf-gcc
VASM = ~/amiga/bin/vasmm68k_mot
KINGCON = ~/amiga/bin/kingcon
DEBUG = 1

CCFLAGS = -g -MP -MMD -m68000 -Ofast -nostdlib -Wextra -Wno-unused-function -Wno-volatile-register-var -fomit-frame-pointer -fno-tree-loop-distribution -flto -fwhole-program -fno-exceptions
LDFLAGS = -Wl,--emit-relocs,-Ttext=0,-Map=$(OUT).map
VASMFLAGS = -m68000 -Felf -opt-fconst -nowarn=62 -dwarf=3 -x -DDEBUG=$(DEBUG)

FSUAE = /Applications/FS-UAE-3.app/Contents/MacOS/fs-uae
FSUAEFLAGS = --hard_drive_0=./out --floppy_drive_0_sounds=off --video_sync=1 --automatic_input_grab=0

all: $(OUT).exe

run: $(OUT).exe
	@echo sys:a.exe > out/s/startup-sequence
	$(FSUAE) $(FSUAEFLAGS)

run-dist: $(OUT).shrinkled.exe
	@echo sys:a.shrinkled.exe > out/s/startup-sequence
	$(FSUAE) $(FSUAEFLAGS)

dist: DEBUG = 0
dist: $(OUT).shrinkled.exe

$(OUT).shrinkled.exe: $(OUT).exe
	Shrinkler -h -9 -T decrunch.txt $< $@

$(OUT).exe: $(OUT).elf
	$(info Elf2Hunk $(program).exe)
	@elf2hunk $(OUT).elf $(OUT).exe -s

$(OUT).elf: $(objects)
	$(info Linking $(program).elf)
	$(CC) $(CCFLAGS) $(LDFLAGS) $(objects) -o $@
	@m68k-amiga-elf-objdump --disassemble --no-show-raw-ins --visualize-jumps -S $@ >$(OUT).s

clean:
	$(info Cleaning...)
	@$(RM) obj/* out/*.*

# -include $(deps)

$(vasm_objects): obj/%.o : src/%.asm $(data)
	$(info )
	$(info Assembling $<)
	@$(VASM) $(VASMFLAGS) -o $@ $(CURDIR)/$<

$(deps): obj/%.d : src/%.asm
	$(info Building dependencies for $<)
	$(VASM) $(VASMFLAGS) -depend=make -o $(patsubst %.d,%.o,$@) $(CURDIR)/$< > $@

data/girl-head.BPL : assets/girl-head.png
	$(KINGCON) $< data/girl-head -F=3 -I -M
data/girl-body.BPL : assets/girl-body.png
	$(KINGCON) $< data/girl-body -F=3 -I

# dude_images := $(wildcard assets/dude_walking_16_frames/*.iff)
# dude_images_png := $(addprefix data/dude_walking_16_frames/, $(patsubst %.iff,%.png,$(notdir $(dude_images))))
# dude_images_raw := $(addprefix data/dude_walking_16_frames/raw/, $(patsubst %.iff,%.raw,$(notdir $(dude_images))))

# data/dude_walking_16_frames/%.png : assets/dude_walking_16_frames/%.iff
# 	convert -extent 96x160 -gravity SouthWest -background "#000000" $< $@

# data/dude_walking_16_frames/raw/%.raw : data/dude_walking_16_frames/%.png
# 	 ~/amiga/bin/amigeconv -f bitplane -d 3 $< $@


tex = assets/bokeh-bright.jpg

data/tex-pal.png: $(tex) Makefile
	convert $< -depth 4 $@

data/tex.png: $(tex) data/tex-pal.png
	convert $< -resize 64x64 -dither FloydSteinberg -remap data/tex-pal.png $@

data/tex.rgba: data/tex.png
	convert $^ -depth 4 $@

data/tex.rgb: data/tex.rgba
	amigatools shiftrgba $^ $@

data/tables_shade1.i: scripts/table_shade.js
	node $^ -v 122 -u 82 --routine=false --aspect=0.75 > $@

obj/tables_shade1.o: data/tables_shade1.i
	$(VASM) -Fbin -quiet $(INCLUDE) -no-opt -o $@ $^

.PHONY: all clean dist
