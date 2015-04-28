#!/bin/bash

# Set default search paths here
include_paths=("/include" "/usr/local/include" "/usr/include")

analyzed_files=()
graph_gen=""
find_header_depends() {
    if [[ $2 == "" ]]; then
        graph_gen=$graph_gen"\"Header Graph\" -> ""\"$1\""";\n"
    else
        graph_gen=$graph_gen"\"$2\""" -> ""\"$1\""";\n"
    fi
    for e in "${analyzed_files[@]}"; do [[ $e == $1 ]] && return; done
    analyzed_files=("${analyzed_files[@]}" "$1") # Prevent recursion
    while read line; do
        parsedline=$(echo $line | grep -o "[\"'<][A-Za-z0-9\._\-\\\/]*[\"'>]")
	includefile=$(echo $parsedline | grep -o "[A-Za-z0-9\._\-\\\/]*")
        if [[ ${parsedline:0:1} = "<" ]]; then
            # Relative include
            get_headers $includefile $1
        else
            # Absolute include
            if [[ $includefile = /* ]]; then
                get_headers $includefile $1
            else
                get_headers $(basename $1)"/"$includefile $1
            fi
        fi
    done < <(grep -o "^\ *#\ *include\ *[\"'<][A-Za-z0-9\._\-\\\/]*[\"'>]" $1)
}

get_headers() {
    statok=false
    hdr=$1
    if [[ $hdr = /* ]]; then
        # Absolute directory
        if [[ -f $hdr ]]; then
            statok=true
        fi
    else
        # Relative location
	for path in ${include_paths[@]}; do
            hdr=$path"/"$1
            if [[ -f $hdr ]]; then
                statok=true;
                break;
            fi
        done;
    fi
    if [[ $statok = false ]]; then
        echo "Could not locate header" $1
        return
    fi
    find_header_depends $hdr $2
}

usage() {
    echo "Usage: $0 [-I /opt/include] -l header.h"
    exit 1
}

if [[ $1 = "" ]]; then
    usage
fi

graph_gen="digraph G {\n"
while getopts ":l:I:" o; do
    case "${o}" in
        l)
            get_headers ${OPTARG}
            ;;
        I)
            include_paths=("${OPTARG}" "${include_paths[@]}")
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
graph_gen=$graph_gen"}\n"

echo -e $graph_gen | dot -Txlib
