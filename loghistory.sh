_loghistory() {

# Detailed history log of shell activities, including time stamps, working directory etc.
#
# Based on 'hcmnt' by Dennis Williamson - 2009-06-05 - updated 2009-06-19
# (http://stackoverflow.com/questions/945288/saving-current-directory-to-bash-history)
#
# Add this function to your '~/.bashrc':
#
# Set the bash variable PROMPT_COMMAND to the name of this function and include
# these options:
#
#     e - add the output of an extra command contained in the histentrycmdextra variable
#     h - add the hostname
#     y - add the terminal device (tty)
#     n - don't add the directory
#     t - add the from and to directories for cd commands
#     l - path to the log file (default = $HOME/.bash_log)
#     ext or a variable
#
# See bottom of this function for examples.
#

    # make sure this is not changed elsewhere in '.bashrc';
    # if it is, you have to update the reg-ex's below
    export HISTTIMEFORMAT="[%F %T] ~~~ "

    local script=$FUNCNAME
    local histentrycmd=
    local cwd=
    local extra=
    local text=
    local logfile="$HOME/.bash_log"
    local hostname=
    local histentry=
    local histleader=
    local datetimestamp=
    local histlinenum=
    local options=":hyntel:"
    local option=
    OPTIND=1
    local usage="Usage: $script [-h] [-y] [-n|-t] [-e] [text] [-l logfile]"

    local ExtraOpt=
    local NoneOpt=
    local ToOpt=
    local tty=
    local ip=

    # *** process options to set flags ***

    while getopts $options option
    do
        case $option in
            h ) hostname=$HOSTNAME;;
            y ) tty=$(tty);;
            n ) if [[ $ToOpt ]]
                then
                    echo "$script: can't include both -n and -t."
                    echo $usage
                    return 1
                else
                    NoneOpt=1       # don't include path
                fi;;
            t ) if [[ $NoneOpt ]]
                then
                    echo "$script: can't include both -n and -t."
                    echo $usage
                    return 1
                else
                    ToOpt=1         # cd shows "from -> to"
                fi;;
            e ) ExtraOpt=1;;        # include histentrycmdextra
            l ) logfile=$OPTARG;;
            : ) echo "$script: missing filename: -$OPTARG."
                echo $usage
                return 1;;
            * ) echo "$script: invalid option: -$OPTARG."
                echo $usage
                return 1;;
        esac
    done

    text=($@)                       # arguments after the options are saved to add to the comment
    text="${text[*]:$OPTIND - 1:${#text[*]}}"

    # add the previous command(s) to the history file immediately
    # so that the history file is in sync across multiple shell sessions
    history -a

    # grab the most recent command from the command history
    histentry=$(history 1)

    # parse it out
    histleader=`expr "$histentry" : ' *\([0-9]*  \[[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*\]\)'`
    histlinenum=`expr "$histleader" : ' *\([0-9]*  \)'`
    datetimestamp=`expr "$histleader" : '.*\(\[[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*\]\)'`
    histentrycmd=${histentry#*~~~ }

    # protect against relogging previous command
    # if all that was actually entered by the user
    # was a (no-op) blank line
    if [[ -z $__PREV_HISTLINE || -z $__PREV_HISTCMD ]]
    then
        # new shell; initialize variables for next command
        export __PREV_HISTLINE=$histlinenum
        export __PREV_HISTCMD=$histentrycmd
        return
    elif [[ $histlinenum == $__PREV_HISTLINE  && $histentrycmd == $__PREV_HISTCMD ]]
    then
        # no new command was actually entered
        return
    else
        # new command entered; store for next comparison
        export __PREV_HISTLINE=$histlinenum
        export __PREV_HISTCMD=$histentrycmd
    fi

    if [[ -z $NoneOpt ]]            # are we adding the directory?
    then
        if [[ ${histentrycmd%% *} == "cd" || ${histentrycmd%% *} == "jd" ]]    # if it's a cd command, we want the old directory
        then                             #   so the comment matches other commands "where *were* you when this was done?"
            if [[ -z $OLDPWD ]]
            then
                OLDPWD="$HOME"
            fi
            if [[ $ToOpt ]]
            then
                cwd="$OLDPWD -> $PWD"    # show "from -> to" for cd
            else
                cwd=$OLDPWD              # just show "from"
            fi
        else
            cwd=$PWD                     # it's not a cd, so just show where we are
        fi
    fi

    if [[ $ExtraOpt && $histentrycmdextra ]]    # do we want a little something extra?
    then
        extra=$(eval "$histentrycmdextra")
    fi

    # strip off the old ### comment if there was one so they don't accumulate
    # then build the string (if text or extra aren't empty, add them with some decoration)
    histentrycmd="${datetimestamp} ${text:+[$text] }${tty:+[$tty] }${ip:+[$ip] }${extra:+[$extra] }~~~ ${hostname:+$hostname:}$cwd ~~~ ${histentrycmd# * ~~~ }"
    # save the entry in a logfile
    echo "$histentrycmd" >> $logfile || echo "$script: file error." ; return 1

} # END FUNCTION _loghistory