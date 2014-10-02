_ariadne() { # was _loghistory :)
# Modified for zsh - Gordon Wells 2014/08

# Detailed history log of shell activities, including time stamps, working directory etc.
#
## Add something like the following to ~/.zshrc:
# source ariadne.zsh
# precmd() {
#     _ariadne -h -t -u 
# }
##
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
#     u - add the username
#     n - don't add the directory
#     t - add the from and to directories for cd commands
#     l - path to the log file (default = $HOME/.bash_log)
#     ext or a variable
#
# See bottom of this function for examples.
#

    local script=$FUNCNAME
    local histentrycmd=
    local cwd=
    local extra=
    local text=
    local logfile="$HOME/.zsh_log"
    local hostname=
    local histentry=
    local histleader=
    local datetimestamp=
    local histlinenum=
    local username=
    local options=":hyunte:l:"
    local option=
    OPTIND=1
    local usage="Usage: $script [-h] [-y] [-u] [-n|-t] [-e] [text] [-l logfile]"

    local ExtraOpt=
    local NoneOpt=
    local ToOpt=
    local tty=
    local ip=

    # *** process options to set flags ***

    while getopts $options option
    do
        case $option in
            h ) hostname=$(hostname);;
            y ) tty=$(tty);;
            u ) username=$USER;;
            n ) if [[ -n $ToOpt ]]
                then
                    echo "$script: can't include both -n and -t."
                    echo $usage
                    return 1
                else
                    NoneOpt=1       # don't include path
                fi;;
            t ) if [[ -n $NoneOpt  ]]
                then
                    echo "$script: can't include both -n and -t."
                    echo $usage
                    return 1
                else
                    ToOpt=1         # cd shows "from -> to"
                fi;;
            e ) ExtraOpt=1;histentrycmdextra=$OPTARG;;        # include histentrycmdextra
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
    fc -AI

    # grab the most recent command from the command history
    histentry=$(fc -i -l -1 -1)
    histentrycmd=$(fc -l -n -1 -1)

    # parse it out
    [[ $histentry =~ "[0-9]* *[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*" ]] && histleader=$MATCH
    [[ $histleader =~ "[0-9]*" ]] && histlinenum=$MATCH
    [[ $histleader =~ "[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*" ]] && datetimestamp=$MATCH

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
        if [[ ${histentrycmd%% *} == "cd" \
         || ${histentrycmd%% *} == "j"  \
         || $histentrycmd%% =~ "^~" ]]    # if it's a cd command, we want the old directory
         # modified for autjump (j) and named directories (~), not sure how to deal with autocd
         # Doesn't detect failure to change to restricted directories
        then                             #   so the comment matches other commands "where *were* you when this was done?"
            if [[ -z $OLDPWD ]]
            then
                OLDPWD="$HOME"
            fi
            if [[ -n $ToOpt ]]
            then
                cwd="$OLDPWD -> $PWD"    # show "from -> to" for cd
            else
                cwd=$OLDPWD              # just show "from"
            fi
        else
            cwd=$PWD                     # it's not a cd, so just show where we are
        fi
    fi

    if [[ -n $ExtraOpt && -n $histentrycmdextra ]]    # do we want a little something extra?
    then
        extra=$(eval ${histentrycmdextra})
    fi

    # build the string (if text or extra aren't empty, add them with some decoration)
    # histentrycmd="${datetimestamp} ${text:+[$text] }${tty:+[$tty] }${ip:+[$ip] }${extra:+[$extra] }~~~ ${hostname:+$hostname:}$cwd ~~~ ${histentrycmd# * ~~~ }"
    histentrycmd="${histentrycmd} ### ${datetimestamp} , ${histlinenum} , ${username:+$username@}${hostname:+$hostname:}${cwd} ,  ${tty:+[$tty] } , ${ip:+[$ip] } , ${extra:+[$extra] }"
    
    # save the entry in a logfile
    echo "$histentrycmd" >> $logfile || echo "$script: file error." ; return 1

} # END FUNCTION _loghistory

function exists { which $1 &> /dev/null }
# if percol is installed, use it to search .zsh_log to retrieve old command or the directory in which it was executed
# modified from https://github.com/mooz/percol#zsh-history-search

if exists percol; then
    function percol_sel_log_history_cwd() {
        local tac
        exists gtac && tac="gtac" || { exists tac && tac="tac" || { tac="tail -r" } }
        BUFFER=$(awk 'BEGIN {FS="###"} {ORS=" "; print substr($0,0, length($0) -length($NF)); split($(NF),a,","); split(a[3],b,"[@: ]"); ORS="\n"; print b[4]}' ~/.zsh_log | percol | awk 'BEGIN {FS="###"} {print $2}')
        CURSOR=$#BUFFER         # move cursor
        zle -R -c               # refresh
    }

    zle -N percol_sel_log_history_cwd
    bindkey '^W' percol_sel_log_history_cwd
fi

if exists percol; then
    function percol_sel_log_history() {
        local tac
        exists gtac && tac="gtac" || { exists tac && tac="tac" || { tac="tail -r" } }
        BUFFER=$(awk 'BEGIN {FS="###"} {ORS=" "; print substr($0,0, length($0) -length($NF)); split($(NF),a,","); split(a[3],b,"[@: ]"); ORS="\n"; print b[4]}' ~/.zsh_log | percol | awk 'BEGIN {FS="###"} {print $1}')
        CURSOR=$#BUFFER         # move cursor
        zle -R -c               # refresh
    }

    zle -N percol_sel_log_history
    bindkey '^R' percol_sel_log_history
fi

