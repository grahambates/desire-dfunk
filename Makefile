name=a
program=out/a

BUILD=elf
DEBUG = 1

CC = m68k-amiga-elf-gcc
VASM = ~/amiga/bin/vasmm68k_mot
VLINK = ~/amiga/bin/vlink
VLINKFLAGS = -bamigahunk -Bstatic
KINGCON = ~/amiga/bin/kingcon
AMIGATOOLS = ~/.nvm/versions/node/v16.17.0/bin/amigatools
CCFLAGS = -g -MP -MMD -m68000 -Ofast -nostdlib -Wextra -Wno-unused-function -Wno-volatile-register-var -fomit-frame-pointer -fno-tree-loop-distribution -flto -fwhole-program -fno-exceptions
LDFLAGS = -Wl,--emit-relocs,-Ttext=0,-Map=$(program).map
VASMFLAGS = -m68000 -opt-fconst -nowarn=62 -x -DDEBUG=$(DEBUG)
FSUAE = /Applications/FS-UAE-3.app/Contents/MacOS/fs-uae
FSUAEFLAGS = --hard_drive_0=./out --floppy_drive_0_sounds=off --video_sync=1 --automatic_input_grab=0

exe = $(name).$(BUILD).exe
sources := $(wildcard src/*.asm)
elf_objects := $(addprefix obj/, $(patsubst %.asm,%.elf,$(notdir $(sources))))
hunk_objects := $(addprefix obj/, $(patsubst %.asm,%.o,$(notdir $(sources))))
deps := $(elf_objects:.elf=.d)

data = obj/tables_shade1.o

all: out/$(exe)
	cp $< $(program).exe

run: all
	@echo sys:$(name).exe > out/s/startup-sequence
	$(FSUAE) $(FSUAEFLAGS)

# BUILD=dist (shrinkled)
out/$(name).dist.exe: out/$(name).elf.exe
	Shrinkler -h -9 -T decrunch.txt $< $@

# BUILD=hunk (vasm/vlink)
out/$(name).hunk.exe: $(hunk_objects) out/$(name).hunk-debug.exe
	$(info Linking (stripped) $@)
	$(VLINK) $(VLINKFLAGS) -S $(hunk_objects) -o $@
out/$(name).hunk-debug.exe: $(hunk_objects)
	$(info Linking $@)
	$(VLINK) $(VLINKFLAGS) $(hunk_objects) -o $@
$(hunk_objects): obj/%.o : src/%.asm $(data)
	$(info )
	$(info Assembling $@)
	@$(VASM) $(VASMFLAGS) -Fhunk -linedebug -o $@ $(CURDIR)/$<

# BUILD=elf (GCC/Bartman)
out/$(name).elf.exe: $(program).elf
	$(info Elf2Hunk $@)
	@elf2hunk $< $@ -s
$(program).elf: $(elf_objects)
	$(info Linking $@)
	$(CC) $(CCFLAGS) $(LDFLAGS) $(elf_objects) -o $@
	@m68k-amiga-elf-objdump --disassemble --no-show-raw-ins --visualize-jumps -S $@ >$(program).dasm.txt
$(elf_objects): obj/%.elf : src/%.asm $(data)
	$(info )
	$(info Assembling $<)
	@$(VASM) $(VASMFLAGS) -Felf -dwarf=3 -o $@ $(CURDIR)/$<

clean:
	$(info Cleaning...)
	@$(RM) obj/* out/*.*

-include $(deps)

$(deps): obj/%.d : src/%.asm
	$(info Building dependencies for $<)
	$(VASM) $(VASMFLAGS) -quiet -depend=make -o $(patsubst %.d,%.elf,$@) $(CURDIR)/$< > $@
	$(VASM) $(VASMFLAGS) -quiet -depend=make -o $(patsubst %.d,%.o,$@) $(CURDIR)/$< >> $@


#-------------------------------------------------------------------------------
# Data:
#-------------------------------------------------------------------------------

# Tunnel tables:
data/tables_shade1.i: scripts/table_shade.js
	node $^ -v 112 -u 82 --routine=false --aspect=0.75 > $@
obj/tables_shade1.o: data/tables_shade1.i
	$(VASM) -Fbin -quiet -no-opt -o $@ $^


#-------------------------------------------------------------------------------
# Images:
#-------------------------------------------------------------------------------

# Tunnel
tex = assets/bokeh-bright.jpg
data/tex-pal.png: $(tex) Makefile
	convert $< -depth 4 $@
data/tex.png: $(tex) data/tex-pal.png
	convert $< -resize 64x64 -dither FloydSteinberg -remap data/tex-pal.png $@
data/tex.rgba: data/tex.png
	convert $^ -depth 4 $@
data/tex.rgb: data/tex.rgba
	$(AMIGATOOLS) shiftrgba $^ $@

# Girl:
data/girl-head.BPL : assets/girl-head.png
	$(KINGCON) $< data/girl-head -F=3 -I -M
data/girl-body.BPL : assets/girl-body.png
	$(KINGCON) $< data/girl-body -F=3 -I
data/credit-gigabates.BPL : assets/credit-gigabates.png
	$(KINGCON) $< data/credit-gigabates -F=1
data/credit-maze.BPL : assets/credit-maze.png
	$(KINGCON) $< data/credit-maze -F=1
data/credit-steffest.BPL : assets/credit-steffest.png
	$(KINGCON) $< data/credit-steffest -F=1

# Vertical logo for tentacles
data/DFunk-vert.SPR : assets/DFunk-vert.png
	$(KINGCON) $< data/DFunk-vert -F=s16 -SX=128

# Static logo screen
data/dfunk_ordered.BPL : assets/dfunk_ordered.iff
	$(KINGCON) $< data/dfunk_ordered -F=5 -C

# Dude walking
data/dude_walking.BPL : $(wildcard assets/walking_dude_v2/*.iff)
	$(KINGCON) assets/walking_dude_v2/1.iff data/dude_walking -I -A -F=3 -C
data/dude-bg.BPL : assets/dude-walking-bg2.png
	$(KINGCON) assets/dude-walking-bg2.png data/dude-bg -F=2 -C=8
data/lamppost.SPR : assets/lamppost.png
	$(KINGCON) $< data/lamppost -F=s16 -SX=128

# Font data
data/font.i : scripts/font-paths.js
	node scripts/font-paths.js > data/font.i data/persp.i
# Perspective data
data/persp.i :  scripts/persp.js
	node scripts/persp.js > data/persp.i

.PHONY: all clean dist
