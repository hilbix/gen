#!/bin/bash
#
# This is a no-brainer straight-forward configuration generator script done in a hurry:
#
# Pepare:
# - This script is gen/gen.sh
# - ln -s gen/Makefile .
# - make
#
# Processes all *.* files.  Creates out/file from description in file.
#
# Description in file looks like:
#
# # comment		comments and completely empty lines (no SPC, no CR!) are ignored
# dir file file..	include files in std/dir/file
# *macro arg..		process dir/.macro with first arg {1}, second arg {2} and so on.
# !<line>		delayed line (this is processed/expanded in the parent recursion)
# ?VAR[SPC]<line>	ignore line if VAR is unknown or empty
# ??VAR[SPC]<line>	ignore line if VAR is unknown
# ???VAR[SPC]<line>	ignore line if VAR is known
# =VAR[SPC]<line>	set VAR to line
# :var[SPC]<line>	defines the variable to <gather> into, and sets line as separator SEP (can be empty)
# +<gather>		gathers var, SEP separated
# -<gather>		gathers var, SEP SPC separated
# ,<gather>		gathers var, ,SEP separated
# ;<gather>		gathers var, ;SEP separated
#  <line>		output line without the leading SPC
# .<line>		output line without the leading dot
# <line>		output line if nothing above matches
#
# [SPC] is optional SPC or TAB
# std/dir/.head is processed before anything in dir/
# std/dir/.foot is processed after dir/ is processed
#
# {VAR} will be replaced by the VAR contents (not environment).
# If VAR is unknown this is an error!
# VAR names can be made of a-z A-Z 0-9 - _ .
# {NAME} is a predefined variable set to the file processed.
# {} delays expansion.  You will usually do '{}!something' to expand later
#
# If some dir/file (which stems from "dir file.." line) contains a delayed line,
# processing this line is delayed after the "dir file.." statement is completely processed.
# You can delay a line again, such that it is processed later again.  And so on.
# This is to be able to gather options into some variable and then output the option.

# ARG1 = where to put the output
# ARG2 = where are the files to include
DEST="${1:-out}"
STD="${2:-std}"

# You need not change anything below

HERE="$(dirname -- "$0")" || exit

# some bash helpers, see also https://github.com/hilbix/bashy
STDOUT() { local e=$?; printf '%s\n' "$(printf '%q' "$1"; [ 1 -lt "$#" ] && printf ' %q' "${@:2}")"; return $e; }
STDERR() { STDOUT "$@" >&2; }
OOPSE() { printf '#E#%q#%d#%d#%q#\n' "$(readlink -m "$1")" "${2:-0}" "${3:-0}" "${*:4}" >&2; STDERR OOPS: "$1:$2" "${@:4}"; exit 23; }
OOPS() { c="$(caller)"; OOPSE "${c#* }" "${c%% *}" '' "$@"; }
o() { "$@" || OOPS fail $?: "$@"; }

# DEBUG=. gen.sh files..
DEBUGSET=()
debugset() { [ -z "$DEBUG" ] || DEBUGSET=("$@"); }
debug() { [ -z "$DEBUG" ] || STDERR debug: "${DEBUGSET[@]}" "$@" || :; }

# safely write output of command to a file
# not changing things on failure
: write-to dir file command args..
write-to()
{
  local TMP="$1/.$2.tmp-" OUT="$1/$2"	# warning: clobber env of "$@"

  if	( "${@:3}" ) >"$TMP"
  then
        [ -s "$TMP" ] || OOPS "$OUT" would be created empty

        cmp -s "$TMP" "$OUT" && o rm -f "$TMP" || o mv -vf "$TMP" "$OUT"
  else
        rm -f "$TMP"
        return 1
  fi
}

# append to a variable in gathering mode
gather()
{
  local g="${2#[	 ]}"

  [ -n "$get" ] || OOPSE "$1" "$nr" 0 gathering not defined

  [ -z "${VARS["$get"]}" ] || g="$3${SEP["$get"]}$4$g"
  VARS["$get"]="${VARS["$get"]}$g"

  debug "$get" += "$g"
}

# extract variable from a line: ${1}${var}[optSPC]$line
getvar()
{
  line="${line#"$1"}"
  var="${line%%[^-a-zA-Z0-9._]*}"
  line="${line#"$var"}"
  line="${line#[	 ]}"
}

# set variable directly
setvar()
{
  debug set "$1" "$2"
  VARS["$1"]="$2"
}

# check variable matching conditional
chkvar()
{
  getvar "$1"
  if	case "$1" in
          (?)	t=set;   [ -n "${VARS["$var"]:+_}" ];;
          (??)	t=def;   [ -n "${VARS["$var"]+_}" ];;
          (???)	t=undef; [ -z "${VARS["$var"]+_}" ];;
          esac
  then
          debug is $t "$var" 'for' "$line"
          true
  else
          debug not $t "$var" 'for' "$line"
          false
  fi
}

# record delayed lines
declare -A delay
delays=()
delayed()
{
  local file nr line tmp=("${delays[@]}")

  debug delays "${tmp[@]}"
  delays=()
  for src in "${tmp[@]}"
  do
        file="${src%:*}"
        nr="${src##*:}"
        line="${delay["$src"]}"
        debug delayed "$src" "$line"
        debugset "$file:$nr"
        process "$line"
  done
}

# process final delays
finish()
{
  while [ -n "$delays" ]
  do
        delayed
  done
}

# run dir/.macro
# usually *macro args..
macro()
{
  local -A orig

  debug macro "$dir/.$var" "$@"

  # prepare {1} {2} ..
  p=0
  for a in "${list[@]}"
  do
        let p++
        [ "${VARS["$p"]+.}" ] && orig["$p"]="${VARS["$p"]}"
        VARS["$p"]="$a"
  done
  o multi "$dir" ".$var"

  # restore {1} {2} ..
  p=0
  for a in "${list[@]}"
  do
        let p++
        unset VARS["$p"]
        [ "${orig["$p"]+.}" ] && VARS["$p"]="${orig["$p"]}"
  done
  :
}

# process a line
# (this rountine is much too long)
declare -A done VARS SEP
process()
{
  local	line="$1"

  case "$line" in
  ('!'*)
        delay["$file:$nr"]="${line#'!'}"
        delays+=("$file:$nr")
        debug delay "${line#'!'}";
        return
        ;;
  ('')	[ -n "$COMPACT" ] && return;;	# ignore empty lines
  esac

  # replace {XXXX} with macro
  let max=1000
  while	[[ $line =~ .*\{([a-zA-Z0-9_][-a-zA-Z0-9_.]*)\}.* ]]
  do
        [ ${VARS[${BASH_REMATCH[1]}]+.} ] || OOPSE "$file" "$nr" 0 cannot replace "${BASH_REMATCH[1]}": unkown "{${BASH_REMATCH[1]}}"
        debug repl "{${BASH_REMATCH[1]}}" by "${VARS[${BASH_REMATCH[1]}]}"
        line="${line//'{'${BASH_REMATCH[1]}'}'/"${VARS[${BASH_REMATCH[1]}]}"}"
        let max-- || OOPSE "$file" "$nr" 0 loop count exeeded: replacing "{${BASH_REMATCH[1]}}" by "${VARS[${BASH_REMATCH[1]}]}"
  done
  # replace {} by nothing, but do this only once
  # (This is very powerful, but as comprehensible as a sendmail configuration.)
  line="${line//'{}'/}"

  # conditionals: ?VAR<line> ??VAR<line> ???VAR<line>
  case "$line" in
  ('???'*)	chkvar '???' || return 0;;	# unknown
  ('??'*)	chkvar '??'  || return 0;;	# set or empty
  ('?'*)	chkvar '?'   || return 0;;	# set and nonempty
  esac
  # line could be altered by conditional, so we have a new "case"

  case "$line" in
  # do the delay again (yes, this is a hack) if we hit something like: {}!...
  ('!'*)	process "$line"; return;;

  # define a variable: =VAR<line>
  ('='*)
        getvar '='
        setvar "$var" "$line"
        return
        ;;
  # gather a variable: =VAR<SEP>
  (':'*)
        getvar ':'
        get="$var"			# remember var name to gather into
        SEP["$get"]="$line"		# remember separator
        VARS["$get"]="${VARS["$get"]}"	# preset var (in case it is unset)
        debug gather "$var" separated by "$line"
        return
        ;;

  # Gather lines starting with + - , ; with different separators:
  # nothing, SPC, comma or semicolon.
  ('+'*)	gather "$file" "${line#'+'}"       ; return;;
  ('-'*)	gather "$file" "${line#'-'}" '' ' '; return;;
  (','*)	gather "$file" "${line#','}" ','   ; return;;
  (';'*)	gather "$file" "${line#';'}" ';'   ; return;;

  # macro processing: *macro arg..
  ('*'*)
        getvar '*'
        o read -ra list <<<"$line"
        macro "$var" "${list[@]}"
        return
        ;;

  # Just feed lines not starting with an ASCII letter unchanged
  (''|[!a-zA-Z]*)
        [ -n "$line" ] || [ -n "$lastline" -a ".$lastfile" = ".$file" ] || return 0
        [ -n "$QUIET" ] || [ ".$lastfile" = ".$file" ] || echo "#I#$file#$nr#0#${delays[*]:- }#"
        lastfile="$file"
        # remove a singlefileSPC or dot from lines (to be able to echo lines starting with A-Za-z)
        line="${line#[ .]}"
        lastline="$line"
        o echo "$line"
        debug out "$line"
        return
        ;;
  esac

  # dir file.. line found

  # Split line into list, space separated
  o read -ra list <<<"$line"

  dir="${list[0]}"
  ensure-valid "$dir" dir

  # do not process delays coming from above
  # actually, this is a hack
  local oldelays=("${delays[@]}")
  delays=()

  once "$dir" .head
  for tpl in "${list[@]:1}"
  do
        ensure-valid "$tpl" file
        o once "$dir" "$tpl"
  done
  nr=-1 once "$dir" .foot

  delayed	# just one step

  # mix our leftover delays with the old ones from before
  delays=("${oldelays[@]}" "${delays[@]}")
}

# check if name is a valid file component (in our context)
: ensure-valid name what
ensure-valid()
{
  case "$1" in
  ([!a-zA-Z0-9_]*)	;;
  (*[!-a-zA-Z0-9_.]*)	;;
  (*[!a-zA-Z0-9_])	;;
  (*)			return;;
  esac
  OOPSE "$file" "$nr" 0 invalid "$2:" "$1"
}

# Just parse this file only once
: once dir file
once()
{
  [ -n "${done["$1/$2"]}" ] || multi "$@"
}

# Allow mutiply parsing of a file (i. E. macros)
: multi dir file
multi()
{
  local dir="$1" tpl="$2" sub

  done["$dir/$tpl"]=:
  # cat the $STD/dir/file combinations
  for sub in "$STD/$dir/$tpl" "$HERE/$STD/$dir/$tpl"
  do
        [ -f "$sub" ] || continue
        debug read: "$sub"
        o parse "$sub"
        return
  done
  case "$tpl" in
  (.*)	return;;
  esac
  OOPSE "$file" "$nr" 0 not found: "$STD/$dir/$tpl"
}

# parse a template file
: parse file NAME
parse()
{
  local get='' nr=0 file="${2:-"$1"}"

  [ -f "$1" ] || OOPS missing "$1"
  while	IFS='' read -r line
  do
        let nr++
        debugset "$1:$nr"

        case "$line" in
        (\#*)	debug ign "$line"; continue;;	# ignore comments
        esac

        process "$line"
  done <"$1"
}

# parse the initial template
: file NAME [target]
template()
{
  debug read: "$1"
  setvar NAME "$2"
  o parse "$1" "$2"
  o finish		# process all still existing delays
  debug done: "$1"
}

# main generator function
gen()
{
  local file="$1" NAME="${1##*/}"

  write-to "$DEST" "$NAME" template "$file" "$NAME" ||
  OOPS gen of "$DEST/$NAME" from "$file" failed
}

o mkdir -p "$DEST"
# Perhaps it seems odd to run for all *.* files
# but this is meant to be easy
# so it just needs to be run from the correct directory
for a in *.*
do
        [ -f "$a" ] || continue

        # ignore backup files
        case "$a" in
        (*~)	continue;;
        esac

        gen "$a"
done

