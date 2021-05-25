onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib Data_Ram_opt

do {wave.do}

view wave
view structure
view signals

do {Data_Ram.udo}

run -all

quit -force
