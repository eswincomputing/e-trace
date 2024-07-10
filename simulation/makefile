# SPDX-License-Identifier: MPL-2.0
#
# Copyright 2024 Beijing ESWIN Computing Technology Co., Ltd.  
#
TOP ?= trenc_top
OUTBIN=./$(TOP).simv
DEF ?= 
DEFS = $(foreach n, $(DEF), +define+$(n))


all: $(OUTBIN) 
	bsub -I -q eri  "vlogan -full64 -kdb +v2k +libext+.v+ +cli +lint=TFIPC-L $(DEFS) -override_timescale=1ns/10ps -sverilog  -file filelist.lst"
	bsub -I -q eri "vcs -full64 -kdb -lca -o $(OUTBIN) -gui -override_timescale=1ps/1fs $(TOP)  +error+100 +lint=TFIPC-L -l elaborate.log"

run:
	bsub -m hpc07 -Ip "$(OUTBIN) -gui | tee run.log"


verdi: 
	bsub -I -q eri "verdi -nologo -simflow -work work -top $(TOP)"&

clean:
	
	@rm -rf vc_hdrs.h ucli.key vsim_compile*.log DEVfiles*csrc inter.vpd
	@rm -rf dump* verdi* run.log runext compile*log elab*log
	@rm -rf 61 AN.DB csrc work.lib++
	@rm -rf core_top.sim* novas*
	@rm -rf *.simv* 

.PHONY: $(OUTBIN)
