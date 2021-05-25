onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+AXI_RAM_I -L xpm -L blk_mem_gen_v8_4_4 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.AXI_RAM_I xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {AXI_RAM_I.udo}

run -all

endsim

quit -force
