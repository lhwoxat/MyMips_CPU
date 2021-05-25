onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib AXI_RAM_I_opt

do {wave.do}

view wave
view structure
view signals

do {AXI_RAM_I.udo}

run -all

quit -force
