#!/bin/bash

outName=fire_01

writeToChip=false
flags="-H"
outext="gb"

while getopts "weD" opt; do
    case $opt in
        w)
            echo "ok good"
            writeToChip=true
            ;;
        e)
            echo "building for emulator"
            flags="-D EMU"
            ;;
        D)
            echo "building for Mega Duck"
            flags="-DTARGET_MEGADUCK -H"
            outext="duck"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

rgbasm -o memory.o memory.asm $flags &&
rgbasm -o main.o main.asm $flags &&
rgblink -n $outName.sym -o $outName.$outext main.o memory.o &&
#rgbfix -v -p 0 -m 0x08 -r 0x1 $outName.$outext
rgbfix -v -p 0 -m MBC5 $outName.$outext

if [ $? -ne 0 ] ; then
    echo "build failed"
    echo "exiting"
    exit $?
fi
echo "done build"



if [ "$writeToChip" != true ] ; then
    echo "not writing"
    exit 0
fi
echo "Writing to chip"
minipro -p "SST39SF020A" -w $outName.$outext -s

