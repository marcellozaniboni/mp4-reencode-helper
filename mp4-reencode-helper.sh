#!/usr/bin/env bash
set -euo pipefail

## Script banner
function showbanner() {
	local license="$1"
	echo "≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"
	echo "| Small video encoding script                          |"
	echo "| version 0.2 - © 2026 Marcello Zaniboni - MIT License |"
	[[ "$license" != "" ]] || echo "| (run without arguments to read the license terms)    |"
	echo "≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"
	echo
	if [ "$license" != "" ]; then
		echo "This software is distributed under MIT license."
		echo "  Permission is hereby granted, free of charge, to any person obtaining a"
		echo "  copy of this software and associated documentation files (the \"Software\"),"
		echo "  to deal in the Software without restriction, including without limitation"
		echo "  the rights to use, copy, modify, merge, publish, distribute, sublicense,"
		echo "  and/or sell copies of the Software, and to permit persons to whom the"
		echo "  Software is furnished to do so."
		echo
		echo "  THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS"
		echo "  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,"
		echo "  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL"
		echo "  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER"
		echo "  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING"
		echo "  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER"
		echo "  DEALINGS IN THESOFTWARE."
		echo
	fi
}

## print an error and exit
function die() {
	echo -e "\e[91merror\e[0m → $*"
	sleep 1
	echo
	exit 1
}

## verify command availability
function need() {
	local cmd=$(which "$1" 2> /dev/null)
	if [ "$cmd" == "" ]; then
		die "command not found: $1"
	fi
}

## print debug message
function debug() {
	# set this to 1 to enable debug messages
	local DEBUG_ENABLED=1
	[[ $DEBUG_ENABLED -ne 1 ]] || echo -e "\e[92mdebug\e[0m → $*"
}

## console input read: choose from a list of options
function prompt_choice() {
	local prompt="$1" def="$2"
	local allowed_name="$3"
	local -n allowed="$allowed_name" # nameref of the array in the parameter
	local x a option
	echo "Choose one of the following ${#allowed[@]} options: ${allowed[*]}" >&2
	# echo -n "for " >&2
	while true; do
		echo -n "$prompt [${def}]: " >&2
		IFS= read -r x
		x="${x:-$def}"
		x="${x,,}"

		for a in "${allowed[@]}"; do
			if [[ "$x" == "${a,,}" ]]; then
				echo "$x"
				echo >&2
				return 0
			fi
		done

		echo "Invalid input. You have to choose one of the following: ${allowed[*]}" >&2
	done
}

## console input read: number
function prompt_number_default() {
	local prompt="$1" def="$2"
	local x re='^[0-9]+([.][0-9]+)?$'
	while true; do
		echo -n "$prompt [${def}]: " >&2
		IFS= read -r x
		x="${x:-$def}"
		[[ "$x" =~ $re ]] && { echo "$x"; return 0; }
		echo "input a number (decimals are allowed, e.g.: 12 or 12.5)" >&2
	done
}

## console input read: optional number
function prompt_number_optional() {
	local prompt="$1"
	local x re='^[0-9]+([.][0-9]+)?$'
	while true; do
		echo -n "$prompt [no limit]: " >&2
		IFS= read -r x
		[[ -z "$x" ]] && { echo ""; return 0; }
		[[ "$x" =~ $re ]] && { echo "$x"; return 0; }
		echo "input a number (optional)" >&2
	done
}

## list of available encoders
function encoder_available() {
	local enc="$1"
	ffmpeg -hide_banner -encoders 2>/dev/null | awk 'length($1)==6 {print $2}' | grep -qx "$enc"
}

## Basic checks

if [ $# -ne 2 ]; then
	showbanner "license"
	die "usage: $0 <input> <output>"
fi

showbanner ""

need "ffmpeg"
need "awk"

IN="$1"
OUT="$2"

if [ ! -f "$IN" ]; then
	die "input file not found: $IN"
fi

out_ext="${OUT##*.}"
[[ "${out_ext,,}" == "mp4" ]] || die "output file extension must be .mp4 (you wrote: $OUT)."

if [[ -e "$OUT" ]]; then
	die "The output file already exists"
fi

## Read user input

PRESET_OPTS=(ultrafast superfast veryfast faster fast medium slow slower veryslow)
PRESET="$(prompt_choice \
	"speed (fast means low quality)" \
	"slow" PRESET_OPTS)"

RES_OPTS=(1080p 720p 480p)
RES="$(prompt_choice \
	"target resolution" \
	"720p" RES_OPTS)"

ROT_OPTS=(0 90 180 270)
ROT="$(prompt_choice \
	"rotation (degrees)" \
	"0" ROT_OPTS)"

AR_OPTS=(none 4:3 14:9 16:9 9:16 1:1 2:1 21:9)
AR="$(prompt_choice \
	"aspect ratio (DAR) (default = no modification)" \
	"none" AR_OPTS)"

CANDIDATES=(libx264 libx265 libaom-av1 libsvtav1)
AVAILABLE=()
for c in "${CANDIDATES[@]}"; do
	encoder_available "$c" && AVAILABLE+=("$c")
done
[[ ${#AVAILABLE[@]} -gt 0 ]] || die "No one of the following ffmpeg encoder is available: ${CANDIDATES[*]}."

DEFAULT_CODEC="libx264"
encoder_available "$DEFAULT_CODEC" || DEFAULT_CODEC="${AVAILABLE[0]}"

VCODEC="$(prompt_choice "video encoder" "$DEFAULT_CODEC" AVAILABLE)"

AUDIO_OPTS=(copy aac)
AUDIO_CHOICE="$(prompt_choice "audio copy or force AAC" "copy" AUDIO_OPTS)"
if [[ "$AUDIO_CHOICE" == "copy" ]]; then
	AUDIO_MODE="copy"
else
	AUDIO_MODE="aac"
fi

echo "Optional trim"
START_S="$(prompt_number_default \
	"- start time in seconds (0 = no cut)" "0")"

END_S="$(prompt_number_optional \
	"- end time in seconds (no answer, no cut)")"

if [[ -n "$END_S" ]]; then
	awk -v s="$START_S" -v e="$END_S" 'BEGIN{ if (e<=s) exit 1; }' \
		|| die "end cut time ($END_S) must be greater than start cut time ($START_S)."
fi

## Compose video filters

VF=()

case "$ROT" in
	0) ;;
	90)  VF+=("transpose=1") ;;
	180) VF+=("transpose=1,transpose=1") ;;
	270) VF+=("transpose=2") ;;
esac

case "$RES" in
	1080p) VF+=("scale=-2:1080") ;;
	720p)  VF+=("scale=-2:720") ;;
	480p)  VF+=("scale=-2:480") ;;
esac

if [[ "$AR" != "none" ]]; then
	VF+=("setdar=${AR/:/\/}")
fi

VF_STR=""
if [[ ${#VF[@]} -gt 0 ]]; then
	VF_STR="$(IFS=','; echo "${VF[*]}")"
fi

## Compose ffmpeg command
CMD=(ffmpeg -hide_banner -y -i "$IN")

# cut (after -i)
[[ "$START_S" != "0" ]] && CMD+=(-ss "$START_S")
[[ -n "$END_S" ]] && CMD+=(-to "$END_S")

# simple MP4: video map + audio (if present), metadata/chapters copy
CMD+=(-map 0:v:0 -map 0:a? -map_metadata 0 -map_chapters 0)

# video codec
CMD+=(-c:v "$VCODEC" -pix_fmt yuv420p)
if [[ "$VCODEC" == "libx264" || "$VCODEC" == "libx265" ]]; then
	CMD+=(-preset "$PRESET")
fi

[[ -n "$VF_STR" ]] && CMD+=(-vf "$VF_STR")

# audio (user's choice)
if [[ "$AUDIO_MODE" == "copy" ]]; then
	CMD+=(-c:a copy)
else
	CMD+=(-c:a aac -b:a 160k)
fi

# web-friendly MP4
CMD+=(-movflags +faststart "$OUT")

## ffmpeg execution
echo
echo "Executing command:"
echo ${CMD[@]}
echo
sleep 1
"${CMD[@]}"

# final report
echo
echo "Done:"
ls -lh "$IN" "$OUT"
