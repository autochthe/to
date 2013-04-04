# to - v1.2.2
# Bookmark locations in bash
#
# Copyright (C) 2013 Mara Kim
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.


### SETTINGS ###

TO_BOOKMARK_DIR=~/.bookmarks

### MAIN ###

to() {
    # create empty bookmarks folder if it does not exist
    if [ ! -d "$TO_BOOKMARK_DIR" ]
    then
        \mkdir "$TO_BOOKMARK_DIR"
    fi

    if [ -z "$1" ]
    then
        # show bookmarks
        for link in $TO_BOOKMARK_DIR/*
        do
            echo "$(\basename $link)" '->' "$(\readlink $link)"
        done
        return 0
    elif [ "$1" = "-h" ]
    then
        _to_help
        return 0
    elif [ "$1" = "-p" ]
    then
        if [ -e "$TO_BOOKMARK_DIR/$2" ]
        then
            # print path of bookmark
            \echo "$(\readlink -f "$TO_BOOKMARK_DIR/$2")"
            return 0
        else
            # echo nothing to prevent strange behavior with $(to -p ...) usage
            return 1
        fi
    elif [ "$1" = "-b" ]
    then
        if [ "$2" ]
        then
            local name="$2"
        else
            local name="$(\basename "$PWD")"
        fi
        if [ -e "$TO_BOOKMARK_DIR/$name" ]
        then
            # remove bookmark
            \rm "$TO_BOOKMARK_DIR/$name"
        fi
        # add bookmark
        if [ "$3" ]
        then
            if [ -d "$3" ]
            then
                \ln -s "$3" "$TO_BOOKMARK_DIR/$name"
            else
                \echo "$3 does not refer to a directory"
                return 1
            fi
        else
            \ln -s "$PWD" "$TO_BOOKMARK_DIR/$2"
        fi
        return 0
    elif [ "$1" = "-r" ]
    then
        if [ -e "$TO_BOOKMARK_DIR/$2" ]
        then
            # remove bookmark
            \rm "$TO_BOOKMARK_DIR/$2"
        fi
        return 0
    fi

    # go to bookmark
    if [ -d "$TO_BOOKMARK_DIR/$1" ]
    then
        \cd -P "$TO_BOOKMARK_DIR/$1"
    else
        \echo "Invalid shortcut: $1"
        return 1
    fi
    return 0
}


### TAB COMPLETION ###

# tab completion generic
# $1 = current word
# $2 = previous word
# Output valid completions
_to() {
    # create empty bookmarks file if it does not exist
    if [ ! -e "$TO_BOOKMARK_DIR" ]
    then
        \mkdir "$TO_BOOKMARK_DIR"
    fi
    # build reply
    local compreply
    if [ "$2" = "-b" ]
    then
        # add current directory
        compreply="$(\basename "$PWD" )"$'\n'"$compreply"
        # get bookmarks
        compreply="$(_to_bookmarks)"$'\n'"$compreply"
    elif [ "$2" = "-r" ]
    then
        # get bookmarks
        compreply="$(_to_bookmarks)"$'\n'"$compreply"
    else
        local subdirs="$(_to_subdirs "$1")"
        if [ "$2" = "-p" ]
        then
            local subfiles="$(_to_subfiles "$1")"
        fi
        if [ "$subdirs" -o "$subfiles" ]
        then
            # add subdirectories
            compreply="$subdirs"$'\n'"$compreply"
            # add subfiles
            compreply="$subfiles"$'\n'"$compreply"
        else
            # get bookmarks (with slash)
            compreply="$(_to_bookmarks "/")"$'\n'"$compreply"
        fi
    fi
    # generate reply 
    \sed -n "/^$(_to_regex "$1").*/p" <<< "$compreply"
}

# tab completion bash
_to_bash() {
    # get components
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    # call generic tab completion function
    local IFS='
'
    COMPREPLY=( $(_to "$cur" "$prev") )
}

# tab completion zsh
_to_zsh() {
    # get components
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    # call generic tab completion function
    local IFS='
'
    COMPREPLY=( $(_to "$cur" "$prev" | \sed "s/[ ']/\\\\&/g" ) )
}

# setup tab completion
if [ "$ZSH_VERSION" ]
then
    \autoload -U +X bashcompinit && \bashcompinit
    \complete -o nospace -F _to_zsh to
else
    \complete -o filenames -o nospace -F _to_bash to
fi


### HELPER FUNCTIONS ###

_to_help() {
    \echo "Usage: to [OPTION] [BOOKMARK]
Set the current working directory to a saved bookmark, or create
such a bookmark.

Options
  -b	Add a new bookmark for current directory (overwrites any current bookmark)
  -r	Remove bookmark
  -p	Print bookmark path
  -h	Show help"
}

# Return list of bookmarks in $TO_BOOKMARK_FILE
# $1 suffix
_to_bookmarks() {
    \find "$TO_BOOKMARK_DIR" -mindepth 1 -maxdepth 1 -type l -printf "%f$1\n"
}

# get the first part of the path
_to_path_head() {
    \sed -n "s/^\([^/]*\)\(\/.*\)\?$/\1/p" <<<"$1"
}

# get the rest of the path
_to_path_tail() {
    \sed -n "s/^[^/]*\(\/.*\)$/\1/p" <<<"$1"
}

# clean input for sed search
_to_regex() {
    if [ "$1" = "/" ]
    then
        # special case for root dir
        \echo
    else
        \echo "$1" | \sed 's/[\/&]/\\&/g'
    fi
}

# find the directories that could be subdirectory expansions of
# $1 word
_to_subdirs() {
    \find "$(\readlink "$TO_BOOKMARK_DIR/$(_to_path_head "$1")")" -mindepth 1 -maxdepth 1 -type d 2> /dev/null | \sed "s@^$(\readlink "$TO_BOOKMARK_DIR/$(_to_path_head "$1")")@$(_to_path_head "$1")@"
}

# find the files that could be subdirectory expansions of
# $1 word
_to_subfiles() {
    \find "$TO_BOOKMARK_DIR/$1" -mindepth 1 -maxdepth 1 -type f 2> /dev/null | \sed "s@^$TO_BOOKMARK_DIR/@@"
}

