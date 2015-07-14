#!/bin/bash
#set -x
# diff2html implemented as a bash 3.2+ script
# inspired by diff2html python script from Yves Bailly <diff2html@tuxfamily.org>
# http://kafka.fr.free.fr/diff2html/#INSTALL
#
# Copyright (C) 2009 Kirk Roybal <kirk@webfinish.com>
# (C) 2009 WebFinish
# http://kirk.webfinish.com
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION=.07

system=$(uname -s)

defaultcss='
<style>
TABLE { border-collapse: collapse; border-spacing: 0px; }
TD.linenum { color: #909090; 
   text-align: right;
   vertical-align: top;
   font-weight: bold;
   border-right: 1px solid black;
   border-left: 1px solid black; }
TD.added { background-color: #DDDDFF; }
TD.modified { background-color: #BBFFBB; }
TD.removed { background-color: #FFCCCC; }
TD.normal { background-color: #FFFFE1; }
</style>
'

function usage () {
   cat <<EOS
${0} - Formats diff(1) output to an HTML page on stdout
http://kirk.webfinish.com/diff2html

Usage: ${0} [--help] [--copyleft] [--debug] [--no-style] [--no-header] [--only-changes] [--style-sheet file.css] [diff options] file1 file2

--help                 This message
--only-changes         Do not display lines that have no differences
--style-sheet file.css Use an alternative style sheet URL
--no-style             Suppress the inclusion of a style sheet
--no-header            Suppress the HTML,HEAD and BODY tags
--debug                Way too much output for you
--copyleft             Show the GNU v3 license
--version              Show the version number and exit
diff options           All other parameters are passed to diff

Examples:
diff2html file1.txt file2.txt > differences.html

Treat all files as text and compare  them  line-by-line, even if they do 
not seem to be text.
diff2html -a file1 file2 > differences.html

The same, but use the alternate style sheet contained in diff_style.css
diff2html --style-sheet diff_style.css -a file1 file2 > differences.html

Pipe stdout of diff to stdin of $0 (slightly faster)
diff file1 file2 | $0 [options] file1 file2

The default, hard-coded style sheet is the following: ${defaultcss}
Note 1: if you give invalid additionnal options to diff(1), diff2html will
        silently ignore this, but the resulting HTML page will be incorrect;

bash version of diff2html is released under the GNU v3+ GPL.
Feel free to submit bugs or ideas to <kirk@webfinish.com>.
EOS
}

function inarray_changed() {
START=0
let STOP=${#changed[@]}-1
TEST=$1
while [ $START -lt $STOP ]
do
	
	N=$(( ($START + $STOP)/2 ))
    
    [[ $TEST -gt ${changed[${N}]} ]] && {
        let START=$N+1
    	N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -lt ${changed[${N}]} ]] && {
        let STOP=$N-1
	    N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -eq ${changed[${N}]} ]] && {
        echo "$N"
        return $N
        break
    }    
done

#not in the zero based array
echo "-1"
return -1

}

function inarray_added() {
START=0
let STOP=${#added[@]}-1
TEST=$1
while [ $START -lt $STOP ]
do
	
	N=$(( ($START + $STOP)/2 ))
    
    [[ $TEST -gt ${added[${N}]} ]] && {
        let START=$N+1
	    N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -lt ${added[${N}]} ]] && {
        let STOP=$N-1
	    N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -eq ${added[${N}]} ]] && {
        echo "$N"
        return $N
        break
    }

done

#not in the zero based array
echo "-1"
return -1

}


function inarray_deleted() {
START=0
let STOP=${#deleted[@]}-1
TEST=$1
while [ $START -lt $STOP ]
do
	
	N=$(( ($START + $STOP)/2 ))
    
    [[ $TEST -gt ${deleted[${N}]} ]] && {
        let START=$N+1
    	N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -lt ${deleted[${N}]} ]] && {
        let STOP=$N-1
    	N=$(( ($START + $STOP)/2 ))
    }
    [[ $TEST -eq ${deleted[${N}]} ]] && {
        echo "$N"
        return $N
        break
    }    
done

echo "-1"
return -1

}

function instr () {
    
    for (( strpos=0 ; strpos < ${#1} ; strpos ++ ))
    do
        [[ "${1:${strpos}:${#2}}" == "${2}" ]] && break
    done

    [[ "$strpos" -eq "${#1}" ]] && strpos=-1
    
    echo $strpos
    return $strpos
}    

function str2htm () {
#Get the return value of this function 
# by exec: html=$(str2htm "$MYSTR")

    # Replace ampersand with html code
    s1="${1//&/&amp;}"
    if [ ${#s1} -eq 0 ]
    then
        return 0
    fi
    # Replace < and > with html codes
    s1="${s1//</&lt;}"
    s1="${s1//>/&gt;}"
    # Replace double spaces with nbsp
    #  Improves visual formatting
    s1=${s1//  /&nbsp;&nbsp;}
    # Replace spaces at beginning of line with nbsp
    #  Prevents some browsers from reducing leading spaces
    s1=${s1/# /&nbsp;}
    # Results to stdout
    echo -e "${s1}"
}

onlychanges='false'
diffopts=''
header='true'
debug='false'

#process command line switches
while [ $# -gt 0 ]
do
    case "${1}" in
    "--help")
        usage
        exit
        ;;
    "--only-changes")
        onlychanges="true"
        ;;
    "--style-sheet")
        shift
        defaultcss="<link rel=\"stylesheet\" href=\"${1}\" type=\"text/css\">"
        ;;
    "--no-style")
        defaultcss=""
        ;;
    "--no-header")
        header="false"
        ;;
    "--debug")
        debug="true"
        ;;
    "--copyleft")
        # Show 'em our @55
        tail -n 620 $0 | sed 's/^# //'
        exit
        ;;
    "--version")
        echo $VERSION
        exit
        ;;
    *)
        [[ -f "${1}" ]] || diffopts="${diffopts} ${1}"
        [[ -f "${1}" ]] && {
            #We have our first file parameter
            file1="${1}"
            #Get the comparison file
            shift
            [[ -e "${1}" ]] || {            
                usage
                exit 1
            }
            file2="${1}"
        }
        ;;
    esac
    shift
done

if [ ${#file1} -eq 0 ] || [ ${#file2} -eq 0 ]
then
    echo "No input files given"
    usage
    exit 1
fi

#find out if we got the diff input via stdin
while read -t 1 diffline
do
    diff="${diff}\n${diffline}"
done

if [ ${#diff} -eq 0 ]
then
  #no diff stdin
  #call it on the command line
  diff=`diff ${diffoptions} "${file1}" "${file2}"`
fi

#Thow away the output lines from diff
# < blah1
# ---
# > blah2
#All we care about are numeric indicators
# 3,4c4,7 
diff=`echo -e "${diff}" | sed -e '/^[^[:digit:]]/d'`

declare -a difflines

#Expand what's left into an array
IFS=$'\n'
difflines=(${diff})
difflimit=${#difflines[@]}

#declare some buffer arrays
declare -a changed
declare -a deleted
declare -a added

if [ "${debug}" == "true" ]
then
    echo -e "Diff Count: $difflimit"
    echo -e "<br>Diffs:"
    diffcounter=0
    for (( diffcounter=0 ; diffcounter<=$difflimit ; diffcounter++ ))
    do
      echo -e "<br>${difflines[$diffcounter]}"
    done  
fi

#Create a counter to adjust
# line labels after deleted lines
let delete_offset=0

#Read the differences into the buffer arrays
for (( diffcounter=0 ; diffcounter<${difflimit} ; diffcounter++ ))
do    
    diffline="${difflines[${diffcounter}]}"

    # all valid diff lines match the expression:
    #  [[:digit:]]*,+[[:digit]]+[[:alpha:]][[:digit:]]*,+[[:digit:]]+
    # "case" does some simple file glob style pattern matching, not full regex
    #  it's enough for these 4 cases.
    match="${diffline//[^[:alpha:]]/}"
    case "${diffline}" in
        *,*,*)
           # w,xAy,z
           regex=\([[:digit:]]*\),\([[:digit:]]*\)[[:alpha:]]\([[:digit:]]*\),\([[:digit:]]*\)
           [[ "${diffline}" =~ ${regex} ]] && {
                f1_start=${BASH_REMATCH[1]}
                f1_end=${BASH_REMATCH[2]}
                f2_start=${BASH_REMATCH[3]}
                f2_end=${BASH_REMATCH[4]}
                }
           ;;
        *[acd]*,*)
           # wAy,z
           regex=\([[:digit:]]*\)[[:alpha:]]\([[:digit:]]*\),\([[:digit:]]*\)
           [[ "${diffline}" =~ ${regex} ]] && {
                f1_start=${BASH_REMATCH[1]}
                f1_end=${BASH_REMATCH[1]}
                f2_start=${BASH_REMATCH[2]}
                f2_end=${BASH_REMATCH[3]}
                }
           ;;
        *,*[acd]*)
           # w,xAy
           regex=\([[:digit:]]*\),\([[:digit:]]*\)[[:alpha:]]\([[:digit:]]*\)
           [[ "${diffline}" =~ ${regex} ]] && {
                f1_start=${BASH_REMATCH[1]}
                f1_end=${BASH_REMATCH[2]}
                f2_start=${BASH_REMATCH[3]}
                f2_end=${BASH_REMATCH[3]}
                }
           ;;
        *)
           # wAy
           regex=\([[:digit:]]*\)[[:alpha:]]\([[:digit:]]*\)
           [[ "${diffline}" =~ ${regex} ]] && {
                f1_start=${BASH_REMATCH[1]}
                f1_end=${BASH_REMATCH[1]}
                f2_start=${BASH_REMATCH[2]}
                f2_end=${BASH_REMATCH[2]}
                }
           ;;
    esac

    # How many changes?
    let f1_lc=(${f1_end}-${f1_start})+1
    let f2_lc=(${f2_end}-${f2_start})+1
    
    [[ "$debug" == "true" ]] && {
        echo "<pre>"
        echo "match:    $match"
        echo "diffline: $diffline"
        echo "f1_start: $f1_start"
        echo "f1_end:   $f1_end"
        echo "f2_start: $f2_start"
        echo "f2_end:   $f2_end"
        echo "f1_lc:    $f1_lc"
        echo "f2_lc:    $f2_lc"
        echo "</pre>"
    }

    case $match in
    "c")
        if [[ $f2_lc -lt $f1_lc ]]
        then
            #lines merged, missing lines are "deleted"
            for (( counter=$f1_start ; counter<${f1_start}+${f2_lc} ; counter++ ))
            do
                let dummy=$counter-$delete_offset
                changed[${#changed[@]}]=$dummy
            done

            for (( counter=$f1_start+$f2_lc ; counter<$f1_end+1 ; counter++ ))
            do
                let dummy=$counter-$delete_offset
                deleted[${#deleted[@]}]=$dummy
            done

        elif [[ $f1_lc -lt $f2_lc ]]
        then
            #Lines are split, extra lines are "added"
            for (( counter=$f1_start ; counter<$f1_end+1 ; counter++ )) 
            do
                let dummy=$counter-$delete_offset
                changed[${#changed[@]}]=$dummy
            done

            for (( counter=$f2_start+${f1_lc} ; counter<$f2_end+1 ; counter++ ))
            do
                let dummy=$counter-$delete_offset
                added[${#added[@]}]=$dummy
            done
        else
            for (( counter=$f1_start ; counter<$f1_end+1 ; counter++ ))
            do
                let dummy=$counter-$delete_offset
                changed[${#changed[@]}]=$dummy
            done
        fi
        ;;
    "a")
        for (( counter=$f2_start ; counter<$f2_end+1 ; counter++))
        do
            let dummy=$counter-$delete_offset
            added[${#added[@]}]=$dummy
        done
        ;;
    *)
        for (( counter=$f1_start ; counter<=$f1_end ; counter++ ))
        do
            #(( delete_offset++ ))
            let dummy=$counter-$delete_offset
            deleted[${#deleted[@]}]=$dummy
        done
        ;;
    esac

done 

declare -a file1_lines
declare -a file2_lines

#Read the files into array variables
#  Hmmm, seems to have a small glob size limit
#    Hmmm, Hmmm. Doesn't work in a sub shell
#     where the parent is using redirection anyway
#IFS=$'\n'
#file1_lines=($(< "${file1}"))
#IFS=$'\n'
#file2_lines=($(< "${file2}"))
#IFS=$'$OLDIFS'

#Do it the hard way
#  Redirection is bad here
#   need to find another way
exec 3<>"${file1}"
IFS=$'\n'
while read f1_line
#for f1_line in $(cat ${file1})
do
    file1_lines[${#file1_lines[@]}]="${f1_line}"
done <&3 # < $file1
exec 3>&-

exec 3<>"${file2}"
while read f2_line
#for f2_line in $(cat ${file2})
do
    file2_lines[${#file2_lines[@]}]="${f2_line}"
done <&3 #< $file2
exec 3>&-

changed_lnks="None "
[[ ${#changed[@]} -gt 0 ]] && {
    #Links to named references in HTML
    changed_lnks=""
    for (( counter=0 ; counter<${#changed[@]} ; counter++ ))
    do
        link="${changed[${counter}]}"
        changed_lnks[${#changed_lnks[@]}]="<a href='#${file1}_${link}'>${link}</a>&nbsp; "
    done
}

added_lnks="None "
[[ ${#added[@]} -gt 0 ]] && {
    added_lnks=""
    #Links to named references in HTML
    for (( counter=0 ; counter<${#added[@]} ; counter++ ))
    do
        link=${added[${counter}]}
        added_lnks[${#added_lnks[@]}]="<a href='#${file2}_${link}'>${link}</a>&nbsp; "
    done
}

deleted_lnks="None "
[[ ${#deleted[@]} -gt 0 ]] && {
    deleted_lnks=""
    #Links to named references in HTML
    for (( counter=0 ; counter<${#deleted[@]} ; counter++ ))
    do
        link=${deleted[${counter}]}
        deleted_lnks[${#deleted_lnks[@]}]="<a href='#${file1}_${link}'>${link}</a>&nbsp; "
    done
}

# Printing the HTML header, and various known information
[[ "$header" == "true" ]] && {
    cat <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
 "http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
<head>
    <title>Differences between $file1 and $file2</title>
    $defaultcss
</head>
<body>
EOS
}

# Finding the mdate of a file in various *nix platforms
case "$system" in 
  "Darwin")
      file1_mdate=$(stat -f%-Sc -t "%Y-%m-%d %H:%M:%S" "${file1}")
      file2_mdate=$(stat -f%-Sc -t "%Y-%m-%d %H:%M:%S" "${file2}")
      ;;
  "Linux")
      file1_mdate=$(date -r "${file1}" "+%Y-%m-%d %H:%M:%S")
      file2_mdate=$(date -r "${file2}" "+%Y-%m-%d %H:%M:%S")
      ;;
  *)                    # Cygwin/HP/Unix/yadayada
      #take a stab at it with GNU ls
      file1_mdate=$(ls -l --time-style="+%Y-%m-%d %H:%M:%S" "${file1}" | 
            sed 's/.*\([[:digit:]]\{4\}-[[:digit:]]*-[[:digit:]]* [[:digit:]]*:[[:digit:]]*:[[:digit:]]*\).*/\1/')
      file2_mdate=$(ls -l --time-style="+%Y-%m-%d %H:%M:%S" "${file2}" | 
            sed 's/.*\([[:digit:]]\{4\}-[[:digit:]]*-[[:digit:]]* [[:digit:]]*:[[:digit:]]*:[[:digit:]]*\).*/\1/')
      ;;
esac

cat <<EOS
<table>
<tr><td width="70%">
<table>
    <tr>
        <td class="modified">Modified line(s):&nbsp;</td>
        <td class="modified">`printf '%s' "${changed_lnks[@]}"`</td>
    </tr>
    <tr>
        <td class="added">Added line(s):&nbsp;</td>
        <td class="added">`printf '%s' "${added_lnks[@]}"`</td>
    </tr>
    <tr>
        <td class="removed">Removed line(s):&nbsp;</td>
        <td class="removed">`printf '%s' "${deleted_lnks[@]}"`</td>
    </tr>
</table>
</td>
<td width="30%">
<font size="-2"><i>Generated by <a href="http://kirk.webfinish.com"><b>diff2html</b></a><br>
&copy; 2009 Kirk Roybal, WebFinish<br>
Python version by: Yves Bailly, MandrakeSoft S.A. 2001<br>
<b>diff2html</b> is licensed under the <a href="http://www.gnu.org/copyleft/gpl.html">GNU GPL</a>.</i></font>
</td></tr>
</table>
<hr/>
<table>
    <tr>
        <th>&nbsp;</th>
        <th width="45%"><strong><big>${file1}</big></strong></th>
        <th>&nbsp;</th>
        <th>&nbsp;</th>
        <th width="45%"><strong><big>${file2}</big></strong></th>
    </tr>
    <tr>
        <td width="16">&nbsp;</td>
        <td>
        ${#file1_lines[@]} lines<br/>
        $(cat "${file1}" | wc -c) bytes<br/>
        Last modified : ${file1_mdate} <br>
        <hr/>
        </td>
        <td width="16">&nbsp;</td>
        <td width="16">&nbsp;</td>
        <td>
        ${#file2_lines[@]} lines<br/>
        $(cat "${file2}" | wc -c) bytes<br/>
        Last modified : ${file2_mdate} <br>
        <hr/>
        </td>
    </tr> 
EOS

# Running through the differences...
fl1=0
fl2=0
[[ "$debug" == "true" ]] && {
    echo "\${file1_lines[]} = ${#file1_lines[@]}"
    echo "\${file2_lines[]} = ${#file2_lines[@]}"
}

#process until we reach the end of both comparison files
until [[ "$fl1" -ge "${#file1_lines[@]}" && "$fl2" -ge "${#file2_lines[@]}" ]]
do
    let dummy=$fl2+1
    [[ `inarray_added $dummy` -gt -1 ]] && {
            # This is an added line
            line2=`str2htm "${file2_lines[${fl2}]}"`
            cat <<EOS
    <tr>
        <td class="linenum">&nbsp;</td>
        <td class="added">&nbsp;</td>
        <td width="16">&nbsp;</td>
        <td class="linenum"><a name="${file2}_${dummy}">${dummy}</a></td>
        <td class="added">${line2}</td>
    </tr>
EOS
            (( fl2++ ))
    # found a match, goto top of loop
            continue
        }

    let dummy=${fl1}+1
    [[ `inarray_deleted $dummy` -gt -1 ]] && {
            # This is a deleted line
            line1=$(str2htm "${file1_lines[${fl1}]}")
            cat <<EOS
    <tr>
        <td class="linenum"><a name="${file1}_${dummy}">${dummy}</a></td>
        <td class="removed">${line1}</td>
        <td width="16">&nbsp;</td>
        <td class="linenum">&nbsp;</td>
        <td class="removed">&nbsp;</td>
    </tr>
EOS
            (( fl1++ ))
    # found a match, goto top of loop
             continue
        }


    let dummy=$fl1+1
    [[ `inarray_changed $dummy` -gt -1 ]] && {
            # This is a changed line
            line1=$(str2htm "${file1_lines[${fl1}]}")
            line2=$(str2htm "${file2_lines[${fl2}]}")
            # can't do math inside the heredoc
            let dummy1=${dummy}
            let dummy2=${fl2}+1
            cat <<EOS
     <tr>
        <td class="linenum"><a name="${file1}_${dummy1}">${dummy1}</a></td>
        <td class="modified">${line1}</td>
        <td width="16">&nbsp;</td>
        <td class="linenum">${dummy2}</td>
        <td class="modified">${line2}</td>
    </tr>
EOS
            (( fl1++ ))
            (( fl2++ ))
    # found a match, goto top of loop
             continue
        }

    # These lines have nothing special
    [[ "$onlychanges" == "false" ]] && {
        let dummy1=${fl1}+1
        let dummy2=${fl2}+1
        line1=`str2htm "${file1_lines[${fl1}]}"`
        line2=`str2htm "${file2_lines[${fl2}]}"`
        cat <<EOS
    <tr>
        <td class="linenum">${dummy1}</td>
        <td class="normal">${line1}</td>
        <td width="16">&nbsp;</td>
        <td class="linenum">${dummy2}</td>
        <td class="normal">${line2}</td>
    </tr>
EOS
    }
    (( fl1++ ))
    (( fl2++ ))

done

cat <<EOS  
</table>
<hr/>
<i>Generated by <b>diff2html</b> on $(date +"%Y-%m-%d %H:%M:%S")</i>
EOS

[[ "$header" == "true" ]] && {
    cat <<EOS
    </body>
    </html>
EOS
}

#Successful end
exit

#                     GNU GENERAL PUBLIC LICENSE
#                        Version 3, 29 June 2007
# 
#  Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
#  Everyone is permitted to copy and distribute verbatim copies
#  of this license document, but changing it is not allowed.
# 
#                             Preamble
# 
#   The GNU General Public License is a free, copyleft license for
# software and other kinds of works.
# 
#   The licenses for most software and other practical works are designed
# to take away your freedom to share and change the works.  By contrast,
# the GNU General Public License is intended to guarantee your freedom to
# share and change all versions of a program--to make sure it remains free
# software for all its users.  We, the Free Software Foundation, use the
# GNU General Public License for most of our software; it applies also to
# any other work released this way by its authors.  You can apply it to
# your programs, too.
# 
#   When we speak of free software, we are referring to freedom, not
# price.  Our General Public Licenses are designed to make sure that you
# have the freedom to distribute copies of free software (and charge for
# them if you wish), that you receive source code or can get it if you
# want it, that you can change the software or use pieces of it in new
# free programs, and that you know you can do these things.
# 
#   To protect your rights, we need to prevent others from denying you
# these rights or asking you to surrender the rights.  Therefore, you have
# certain responsibilities if you distribute copies of the software, or if
# you modify it: responsibilities to respect the freedom of others.
# 
#   For example, if you distribute copies of such a program, whether
# gratis or for a fee, you must pass on to the recipients the same
# freedoms that you received.  You must make sure that they, too, receive
# or can get the source code.  And you must show them these terms so they
# know their rights.
# 
#   Developers that use the GNU GPL protect your rights with two steps:
# (1) assert copyright on the software, and (2) offer you this License
# giving you legal permission to copy, distribute and/or modify it.
# 
#   For the developers' and authors' protection, the GPL clearly explains
# that there is no warranty for this free software.  For both users' and
# authors' sake, the GPL requires that modified versions be marked as
# changed, so that their problems will not be attributed erroneously to
# authors of previous versions.
# 
#   Some devices are designed to deny users access to install or run
# modified versions of the software inside them, although the manufacturer
# can do so.  This is fundamentally incompatible with the aim of
# protecting users' freedom to change the software.  The systematic
# pattern of such abuse occurs in the area of products for individuals to
# use, which is precisely where it is most unacceptable.  Therefore, we
# have designed this version of the GPL to prohibit the practice for those
# products.  If such problems arise substantially in other domains, we
# stand ready to extend this provision to those domains in future versions
# of the GPL, as needed to protect the freedom of users.
# 
#   Finally, every program is threatened constantly by software patents.
# States should not allow patents to restrict development and use of
# software on general-purpose computers, but in those that do, we wish to
# avoid the special danger that patents applied to a free program could
# make it effectively proprietary.  To prevent this, the GPL assures that
# patents cannot be used to render the program non-free.
# 
#   The precise terms and conditions for copying, distribution and
# modification follow.
# 
#                        TERMS AND CONDITIONS
# 
#   0. Definitions.
# 
#   "This License" refers to version 3 of the GNU General Public License.
# 
#   "Copyright" also means copyright-like laws that apply to other kinds of
# works, such as semiconductor masks.
# 
#   "The Program" refers to any copyrightable work licensed under this
# License.  Each licensee is addressed as "you".  "Licensees" and
# "recipients" may be individuals or organizations.
# 
#   To "modify" a work means to copy from or adapt all or part of the work
# in a fashion requiring copyright permission, other than the making of an
# exact copy.  The resulting work is called a "modified version" of the
# earlier work or a work "based on" the earlier work.
# 
#   A "covered work" means either the unmodified Program or a work based
# on the Program.
# 
#   To "propagate" a work means to do anything with it that, without
# permission, would make you directly or secondarily liable for
# infringement under applicable copyright law, except executing it on a
# computer or modifying a private copy.  Propagation includes copying,
# distribution (with or without modification), making available to the
# public, and in some countries other activities as well.
# 
#   To "convey" a work means any kind of propagation that enables other
# parties to make or receive copies.  Mere interaction with a user through
# a computer network, with no transfer of a copy, is not conveying.
# 
#   An interactive user interface displays "Appropriate Legal Notices"
# to the extent that it includes a convenient and prominently visible
# feature that (1) displays an appropriate copyright notice, and (2)
# tells the user that there is no warranty for the work (except to the
# extent that warranties are provided), that licensees may convey the
# work under this License, and how to view a copy of this License.  If
# the interface presents a list of user commands or options, such as a
# menu, a prominent item in the list meets this criterion.
# 
#   1. Source Code.
# 
#   The "source code" for a work means the preferred form of the work
# for making modifications to it.  "Object code" means any non-source
# form of a work.
# 
#   A "Standard Interface" means an interface that either is an official
# standard defined by a recognized standards body, or, in the case of
# interfaces specified for a particular programming language, one that
# is widely used among developers working in that language.
# 
#   The "System Libraries" of an executable work include anything, other
# than the work as a whole, that (a) is included in the normal form of
# packaging a Major Component, but which is not part of that Major
# Component, and (b) serves only to enable use of the work with that
# Major Component, or to implement a Standard Interface for which an
# implementation is available to the public in source code form.  A
# "Major Component", in this context, means a major essential component
# (kernel, window system, and so on) of the specific operating system
# (if any) on which the executable work runs, or a compiler used to
# produce the work, or an object code interpreter used to run it.
# 
#   The "Corresponding Source" for a work in object code form means all
# the source code needed to generate, install, and (for an executable
# work) run the object code and to modify the work, including scripts to
# control those activities.  However, it does not include the work's
# System Libraries, or general-purpose tools or generally available free
# programs which are used unmodified in performing those activities but
# which are not part of the work.  For example, Corresponding Source
# includes interface definition files associated with source files for
# the work, and the source code for shared libraries and dynamically
# linked subprograms that the work is specifically designed to require,
# such as by intimate data communication or control flow between those
# subprograms and other parts of the work.
# 
#   The Corresponding Source need not include anything that users
# can regenerate automatically from other parts of the Corresponding
# Source.
# 
#   The Corresponding Source for a work in source code form is that
# same work.
# 
#   2. Basic Permissions.
# 
#   All rights granted under this License are granted for the term of
# copyright on the Program, and are irrevocable provided the stated
# conditions are met.  This License explicitly affirms your unlimited
# permission to run the unmodified Program.  The output from running a
# covered work is covered by this License only if the output, given its
# content, constitutes a covered work.  This License acknowledges your
# rights of fair use or other equivalent, as provided by copyright law.
# 
#   You may make, run and propagate covered works that you do not
# convey, without conditions so long as your license otherwise remains
# in force.  You may convey covered works to others for the sole purpose
# of having them make modifications exclusively for you, or provide you
# with facilities for running those works, provided that you comply with
# the terms of this License in conveying all material for which you do
# not control copyright.  Those thus making or running the covered works
# for you must do so exclusively on your behalf, under your direction
# and control, on terms that prohibit them from making any copies of
# your copyrighted material outside their relationship with you.
# 
#   Conveying under any other circumstances is permitted solely under
# the conditions stated below.  Sublicensing is not allowed; section 10
# makes it unnecessary.
# 
#   3. Protecting Users' Legal Rights From Anti-Circumvention Law.
# 
#   No covered work shall be deemed part of an effective technological
# measure under any applicable law fulfilling obligations under article
# 11 of the WIPO copyright treaty adopted on 20 December 1996, or
# similar laws prohibiting or restricting circumvention of such
# measures.
# 
#   When you convey a covered work, you waive any legal power to forbid
# circumvention of technological measures to the extent such circumvention
# is effected by exercising rights under this License with respect to
# the covered work, and you disclaim any intention to limit operation or
# modification of the work as a means of enforcing, against the work's
# users, your or third parties' legal rights to forbid circumvention of
# technological measures.
# 
#   4. Conveying Verbatim Copies.
# 
#   You may convey verbatim copies of the Program's source code as you
# receive it, in any medium, provided that you conspicuously and
# appropriately publish on each copy an appropriate copyright notice;
# keep intact all notices stating that this License and any
# non-permissive terms added in accord with section 7 apply to the code;
# keep intact all notices of the absence of any warranty; and give all
# recipients a copy of this License along with the Program.
# 
#   You may charge any price or no price for each copy that you convey,
# and you may offer support or warranty protection for a fee.
# 
#   5. Conveying Modified Source Versions.
# 
#   You may convey a work based on the Program, or the modifications to
# produce it from the Program, in the form of source code under the
# terms of section 4, provided that you also meet all of these conditions:
# 
#     a) The work must carry prominent notices stating that you modified
#     it, and giving a relevant date.
# 
#     b) The work must carry prominent notices stating that it is
#     released under this License and any conditions added under section
#     7.  This requirement modifies the requirement in section 4 to
#     "keep intact all notices".
# 
#     c) You must license the entire work, as a whole, under this
#     License to anyone who comes into possession of a copy.  This
#     License will therefore apply, along with any applicable section 7
#     additional terms, to the whole of the work, and all its parts,
#     regardless of how they are packaged.  This License gives no
#     permission to license the work in any other way, but it does not
#     invalidate such permission if you have separately received it.
# 
#     d) If the work has interactive user interfaces, each must display
#     Appropriate Legal Notices; however, if the Program has interactive
#     interfaces that do not display Appropriate Legal Notices, your
#     work need not make them do so.
# 
#   A compilation of a covered work with other separate and independent
# works, which are not by their nature extensions of the covered work,
# and which are not combined with it such as to form a larger program,
# in or on a volume of a storage or distribution medium, is called an
# "aggregate" if the compilation and its resulting copyright are not
# used to limit the access or legal rights of the compilation's users
# beyond what the individual works permit.  Inclusion of a covered work
# in an aggregate does not cause this License to apply to the other
# parts of the aggregate.
# 
#   6. Conveying Non-Source Forms.
# 
#   You may convey a covered work in object code form under the terms
# of sections 4 and 5, provided that you also convey the
# machine-readable Corresponding Source under the terms of this License,
# in one of these ways:
# 
#     a) Convey the object code in, or embodied in, a physical product
#     (including a physical distribution medium), accompanied by the
#     Corresponding Source fixed on a durable physical medium
#     customarily used for software interchange.
# 
#     b) Convey the object code in, or embodied in, a physical product
#     (including a physical distribution medium), accompanied by a
#     written offer, valid for at least three years and valid for as
#     long as you offer spare parts or customer support for that product
#     model, to give anyone who possesses the object code either (1) a
#     copy of the Corresponding Source for all the software in the
#     product that is covered by this License, on a durable physical
#     medium customarily used for software interchange, for a price no
#     more than your reasonable cost of physically performing this
#     conveying of source, or (2) access to copy the
#     Corresponding Source from a network server at no charge.
# 
#     c) Convey individual copies of the object code with a copy of the
#     written offer to provide the Corresponding Source.  This
#     alternative is allowed only occasionally and noncommercially, and
#     only if you received the object code with such an offer, in accord
#     with subsection 6b.
# 
#     d) Convey the object code by offering access from a designated
#     place (gratis or for a charge), and offer equivalent access to the
#     Corresponding Source in the same way through the same place at no
#     further charge.  You need not require recipients to copy the
#     Corresponding Source along with the object code.  If the place to
#     copy the object code is a network server, the Corresponding Source
#     may be on a different server (operated by you or a third party)
#     that supports equivalent copying facilities, provided you maintain
#     clear directions next to the object code saying where to find the
#     Corresponding Source.  Regardless of what server hosts the
#     Corresponding Source, you remain obligated to ensure that it is
#     available for as long as needed to satisfy these requirements.
# 
#     e) Convey the object code using peer-to-peer transmission, provided
#     you inform other peers where the object code and Corresponding
#     Source of the work are being offered to the general public at no
#     charge under subsection 6d.
# 
#   A separable portion of the object code, whose source code is excluded
# from the Corresponding Source as a System Library, need not be
# included in conveying the object code work.
# 
#   A "User Product" is either (1) a "consumer product", which means any
# tangible personal property which is normally used for personal, family,
# or household purposes, or (2) anything designed or sold for incorporation
# into a dwelling.  In determining whether a product is a consumer product,
# doubtful cases shall be resolved in favor of coverage.  For a particular
# product received by a particular user, "normally used" refers to a
# typical or common use of that class of product, regardless of the status
# of the particular user or of the way in which the particular user
# actually uses, or expects or is expected to use, the product.  A product
# is a consumer product regardless of whether the product has substantial
# commercial, industrial or non-consumer uses, unless such uses represent
# the only significant mode of use of the product.
# 
#   "Installation Information" for a User Product means any methods,
# procedures, authorization keys, or other information required to install
# and execute modified versions of a covered work in that User Product from
# a modified version of its Corresponding Source.  The information must
# suffice to ensure that the continued functioning of the modified object
# code is in no case prevented or interfered with solely because
# modification has been made.
# 
#   If you convey an object code work under this section in, or with, or
# specifically for use in, a User Product, and the conveying occurs as
# part of a transaction in which the right of possession and use of the
# User Product is transferred to the recipient in perpetuity or for a
# fixed term (regardless of how the transaction is characterized), the
# Corresponding Source conveyed under this section must be accompanied
# by the Installation Information.  But this requirement does not apply
# if neither you nor any third party retains the ability to install
# modified object code on the User Product (for example, the work has
# been installed in ROM).
# 
#   The requirement to provide Installation Information does not include a
# requirement to continue to provide support service, warranty, or updates
# for a work that has been modified or installed by the recipient, or for
# the User Product in which it has been modified or installed.  Access to a
# network may be denied when the modification itself materially and
# adversely affects the operation of the network or violates the rules and
# protocols for communication across the network.
# 
#   Corresponding Source conveyed, and Installation Information provided,
# in accord with this section must be in a format that is publicly
# documented (and with an implementation available to the public in
# source code form), and must require no special password or key for
# unpacking, reading or copying.
# 
#   7. Additional Terms.
# 
#   "Additional permissions" are terms that supplement the terms of this
# License by making exceptions from one or more of its conditions.
# Additional permissions that are applicable to the entire Program shall
# be treated as though they were included in this License, to the extent
# that they are valid under applicable law.  If additional permissions
# apply only to part of the Program, that part may be used separately
# under those permissions, but the entire Program remains governed by
# this License without regard to the additional permissions.
# 
#   When you convey a copy of a covered work, you may at your option
# remove any additional permissions from that copy, or from any part of
# it.  (Additional permissions may be written to require their own
# removal in certain cases when you modify the work.)  You may place
# additional permissions on material, added by you to a covered work,
# for which you have or can give appropriate copyright permission.
# 
#   Notwithstanding any other provision of this License, for material you
# add to a covered work, you may (if authorized by the copyright holders of
# that material) supplement the terms of this License with terms:
# 
#     a) Disclaiming warranty or limiting liability differently from the
#     terms of sections 15 and 16 of this License; or
# 
#     b) Requiring preservation of specified reasonable legal notices or
#     author attributions in that material or in the Appropriate Legal
#     Notices displayed by works containing it; or
# 
#     c) Prohibiting misrepresentation of the origin of that material, or
#     requiring that modified versions of such material be marked in
#     reasonable ways as different from the original version; or
# 
#     d) Limiting the use for publicity purposes of names of licensors or
#     authors of the material; or
# 
#     e) Declining to grant rights under trademark law for use of some
#     trade names, trademarks, or service marks; or
# 
#     f) Requiring indemnification of licensors and authors of that
#     material by anyone who conveys the material (or modified versions of
#     it) with contractual assumptions of liability to the recipient, for
#     any liability that these contractual assumptions directly impose on
#     those licensors and authors.
# 
#   All other non-permissive additional terms are considered "further
# restrictions" within the meaning of section 10.  If the Program as you
# received it, or any part of it, contains a notice stating that it is
# governed by this License along with a term that is a further
# restriction, you may remove that term.  If a license document contains
# a further restriction but permits relicensing or conveying under this
# License, you may add to a covered work material governed by the terms
# of that license document, provided that the further restriction does
# not survive such relicensing or conveying.
# 
#   If you add terms to a covered work in accord with this section, you
# must place, in the relevant source files, a statement of the
# additional terms that apply to those files, or a notice indicating
# where to find the applicable terms.
# 
#   Additional terms, permissive or non-permissive, may be stated in the
# form of a separately written license, or stated as exceptions;
# the above requirements apply either way.
# 
#   8. Termination.
# 
#   You may not propagate or modify a covered work except as expressly
# provided under this License.  Any attempt otherwise to propagate or
# modify it is void, and will automatically terminate your rights under
# this License (including any patent licenses granted under the third
# paragraph of section 11).
# 
#   However, if you cease all violation of this License, then your
# license from a particular copyright holder is reinstated (a)
# provisionally, unless and until the copyright holder explicitly and
# finally terminates your license, and (b) permanently, if the copyright
# holder fails to notify you of the violation by some reasonable means
# prior to 60 days after the cessation.
# 
#   Moreover, your license from a particular copyright holder is
# reinstated permanently if the copyright holder notifies you of the
# violation by some reasonable means, this is the first time you have
# received notice of violation of this License (for any work) from that
# copyright holder, and you cure the violation prior to 30 days after
# your receipt of the notice.
# 
#   Termination of your rights under this section does not terminate the
# licenses of parties who have received copies or rights from you under
# this License.  If your rights have been terminated and not permanently
# reinstated, you do not qualify to receive new licenses for the same
# material under section 10.
# 
#   9. Acceptance Not Required for Having Copies.
# 
#   You are not required to accept this License in order to receive or
# run a copy of the Program.  Ancillary propagation of a covered work
# occurring solely as a consequence of using peer-to-peer transmission
# to receive a copy likewise does not require acceptance.  However,
# nothing other than this License grants you permission to propagate or
# modify any covered work.  These actions infringe copyright if you do
# not accept this License.  Therefore, by modifying or propagating a
# covered work, you indicate your acceptance of this License to do so.
# 
#   10. Automatic Licensing of Downstream Recipients.
# 
#   Each time you convey a covered work, the recipient automatically
# receives a license from the original licensors, to run, modify and
# propagate that work, subject to this License.  You are not responsible
# for enforcing compliance by third parties with this License.
# 
#   An "entity transaction" is a transaction transferring control of an
# organization, or substantially all assets of one, or subdividing an
# organization, or merging organizations.  If propagation of a covered
# work results from an entity transaction, each party to that
# transaction who receives a copy of the work also receives whatever
# licenses to the work the party's predecessor in interest had or could
# give under the previous paragraph, plus a right to possession of the
# Corresponding Source of the work from the predecessor in interest, if
# the predecessor has it or can get it with reasonable efforts.
# 
#   You may not impose any further restrictions on the exercise of the
# rights granted or affirmed under this License.  For example, you may
# not impose a license fee, royalty, or other charge for exercise of
# rights granted under this License, and you may not initiate litigation
# (including a cross-claim or counterclaim in a lawsuit) alleging that
# any patent claim is infringed by making, using, selling, offering for
# sale, or importing the Program or any portion of it.
# 
#   11. Patents.
# 
#   A "contributor" is a copyright holder who authorizes use under this
# License of the Program or a work on which the Program is based.  The
# work thus licensed is called the contributor's "contributor version".
# 
#   A contributor's "essential patent claims" are all patent claims
# owned or controlled by the contributor, whether already acquired or
# hereafter acquired, that would be infringed by some manner, permitted
# by this License, of making, using, or selling its contributor version,
# but do not include claims that would be infringed only as a
# consequence of further modification of the contributor version.  For
# purposes of this definition, "control" includes the right to grant
# patent sublicenses in a manner consistent with the requirements of
# this License.
# 
#   Each contributor grants you a non-exclusive, worldwide, royalty-free
# patent license under the contributor's essential patent claims, to
# make, use, sell, offer for sale, import and otherwise run, modify and
# propagate the contents of its contributor version.
# 
#   In the following three paragraphs, a "patent license" is any express
# agreement or commitment, however denominated, not to enforce a patent
# (such as an express permission to practice a patent or covenant not to
# sue for patent infringement).  To "grant" such a patent license to a
# party means to make such an agreement or commitment not to enforce a
# patent against the party.
# 
#   If you convey a covered work, knowingly relying on a patent license,
# and the Corresponding Source of the work is not available for anyone
# to copy, free of charge and under the terms of this License, through a
# publicly available network server or other readily accessible means,
# then you must either (1) cause the Corresponding Source to be so
# available, or (2) arrange to deprive yourself of the benefit of the
# patent license for this particular work, or (3) arrange, in a manner
# consistent with the requirements of this License, to extend the patent
# license to downstream recipients.  "Knowingly relying" means you have
# actual knowledge that, but for the patent license, your conveying the
# covered work in a country, or your recipient's use of the covered work
# in a country, would infringe one or more identifiable patents in that
# country that you have reason to believe are valid.
# 
#   If, pursuant to or in connection with a single transaction or
# arrangement, you convey, or propagate by procuring conveyance of, a
# covered work, and grant a patent license to some of the parties
# receiving the covered work authorizing them to use, propagate, modify
# or convey a specific copy of the covered work, then the patent license
# you grant is automatically extended to all recipients of the covered
# work and works based on it.
# 
#   A patent license is "discriminatory" if it does not include within
# the scope of its coverage, prohibits the exercise of, or is
# conditioned on the non-exercise of one or more of the rights that are
# specifically granted under this License.  You may not convey a covered
# work if you are a party to an arrangement with a third party that is
# in the business of distributing software, under which you make payment
# to the third party based on the extent of your activity of conveying
# the work, and under which the third party grants, to any of the
# parties who would receive the covered work from you, a discriminatory
# patent license (a) in connection with copies of the covered work
# conveyed by you (or copies made from those copies), or (b) primarily
# for and in connection with specific products or compilations that
# contain the covered work, unless you entered into that arrangement,
# or that patent license was granted, prior to 28 March 2007.
# 
#   Nothing in this License shall be construed as excluding or limiting
# any implied license or other defenses to infringement that may
# otherwise be available to you under applicable patent law.
# 
#   12. No Surrender of Others' Freedom.
# 
#   If conditions are imposed on you (whether by court order, agreement or
# otherwise) that contradict the conditions of this License, they do not
# excuse you from the conditions of this License.  If you cannot convey a
# covered work so as to satisfy simultaneously your obligations under this
# License and any other pertinent obligations, then as a consequence you may
# not convey it at all.  For example, if you agree to terms that obligate you
# to collect a royalty for further conveying from those to whom you convey
# the Program, the only way you could satisfy both those terms and this
# License would be to refrain entirely from conveying the Program.
# 
#   13. Use with the GNU Affero General Public License.
# 
#   Notwithstanding any other provision of this License, you have
# permission to link or combine any covered work with a work licensed
# under version 3 of the GNU Affero General Public License into a single
# combined work, and to convey the resulting work.  The terms of this
# License will continue to apply to the part which is the covered work,
# but the special requirements of the GNU Affero General Public License,
# section 13, concerning interaction through a network will apply to the
# combination as such.
# 
#   14. Revised Versions of this License.
# 
#   The Free Software Foundation may publish revised and/or new versions of
# the GNU General Public License from time to time.  Such new versions will
# be similar in spirit to the present version, but may differ in detail to
# address new problems or concerns.
# 
#   Each version is given a distinguishing version number.  If the
# Program specifies that a certain numbered version of the GNU General
# Public License "or any later version" applies to it, you have the
# option of following the terms and conditions either of that numbered
# version or of any later version published by the Free Software
# Foundation.  If the Program does not specify a version number of the
# GNU General Public License, you may choose any version ever published
# by the Free Software Foundation.
# 
#   If the Program specifies that a proxy can decide which future
# versions of the GNU General Public License can be used, that proxy's
# public statement of acceptance of a version permanently authorizes you
# to choose that version for the Program.
# 
#   Later license versions may give you additional or different
# permissions.  However, no additional obligations are imposed on any
# author or copyright holder as a result of your choosing to follow a
# later version.
# 
#   15. Disclaimer of Warranty.
# 
#   THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
# APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
# HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
# OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
# IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
# ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
# 
#   16. Limitation of Liability.
# 
#   IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
# WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
# THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
# GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
# USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
# DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
# PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
# EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGES.
# 
#   17. Interpretation of Sections 15 and 16.
# 
#   If the disclaimer of warranty and limitation of liability provided
# above cannot be given local legal effect according to their terms,
# reviewing courts shall apply local law that most closely approximates
# an absolute waiver of all civil liability in connection with the
# Program, unless a warranty or assumption of liability accompanies a
# copy of the Program in return for a fee.
# 
#                      END OF TERMS AND CONDITIONS