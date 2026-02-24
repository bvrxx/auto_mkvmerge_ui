#!/bin/bash

#─────────────────────────────────── user settings ───────────────────────────────────#
#─────────────────────────────────────────────────────────────────────────────────────#
# pathes
input_folder=""
output_folder=""
jsonfile_path="./template.json"
#─────────────────────────────────────────────────────────────────────────────────────#
# determine what to do if the video files have different audio and subtitle tracks
# possible values:
# normal    | if credibility check returns with no errors start merging
# check     | stops after credibility check
# nocheck   | merge without a credibility check
mode=normal
#─────────────────────────────────────────────────────────────────────────────────────#
# choose which mkvmerge version is used
# possible values:
# binary    | use "/usr/bin/mkvmerge"
# flatpak   | use "flatpak run org.bunkus.mkvtoolnix-gui mkvmerge"
# path      | use your own path to mkvmerge
mkvmerge=binary
#─────────────────────────────────────────────────────────────────────────────────────#
# get text notifications of errors and when the script is done (via notify-send)
# possible values:
# on        | notifications on
# off       | notifications off
notification_text=on
#─────────────────────────────────────────────────────────────────────────────────────#
# get audio notifications of errors and when the script is done
# possible values:
# off       | no sound     
# beep      | beep sounds via speaker-test
# voice     | tts via spd-say
# file      | play wav files from $(pwd)./bin folder namend done.wav & error.wav
nofification_audio=beep
#─────────────────────────────────────────────────────────────────────────────────────#
# overwrite the above settings with the values from a ini file
# possible values:
# on        | ignore above values and use $settings_file
# off       | use the  values from script
overwrite_with_settings_ini=on
settings_file="./settings.ini"
#─────────────────────────────────────────────────────────────────────────────────────#
#─────────────────────────────────── script start ────────────────────────────────────#



# ffprobe
ffprobe_path="/usr/bin/ffprobe"


# global variables
declare -a json_array
declare -a video_file_list
outputpath_index=-1
inputpath_index=-1


#colors
RED='\033[0;31m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
WHITE_ON_GRAY='\033[0;37;100m'
BLACK_ON_WHITE='\033[0;30;47m'
WHITE_ON_RED='\033[0;37;41m'
NC='\033[0m' # No Color




# Main Function
main() {

    # get the user variables of the ini file
    if [ "$overwrite_with_settings_ini" = "on" ]; then
        get_user_variables_from_ini_file
    fi

    # convert relativ to absolut pathes
    jsonfile_path=$(relativ_to_fullpath "$jsonfile_path")


    # apply user varible $mkvmerge to $mkvmerge_path
    if [ "$mkvmerge" = "binary" ]; then
        mkvmerge_path="/usr/bin/mkvmerge"
    elif [ "$mkvmerge" = "flatpak" ]; then
        mkvmerge_path="flatpak run org.bunkus.mkvtoolnix-gui mkvmerge"
    else
        mkvmerge_path=$mkvmerge
    fi
    
    

    echo "────────────────────────────────────────────────────────────────"
    echo -e "${BLACK_ON_WHITE}                       Auto MKVMerge start                      ${NC}"
    echo "────────────────────────────────────────────────────────────────"
    echo "                                                                "
    echo -e "${WHITE_ON_GRAY} Input Folder  ${NC} ""$input_folder"""
    echo -e "${WHITE_ON_GRAY} Output Folder ${NC} ""$output_folder"""   
    echo -e "${WHITE_ON_GRAY} JSON File     ${NC} ""$jsonfile_path""" 
    echo -e "${WHITE_ON_GRAY} MKVMerge      ${NC} ""$mkvmerge_path""" 
    echo -e "${WHITE_ON_GRAY} Mode          ${NC} ""$mode"""
    echo "                                                                "  
    echo "────────────────────────────────────────────────────────────────"

    # map json array to bash array
    check_dependecies
    init


    #credibility check
    if [ ! "$mode" = "nocheck" ]; then
        check_credibility "${video_file_list[@]}"
    fi

    #start merging
    if [ ! "$mode" = "check" ]; then
        echo -e "${BLACK_ON_WHITE}                        Starting MKVMerge                       ${NC}"
        local filecount=1 #count variable for the echo output
        local filecountdecimal="" #same count variable in 3 decimal
        local filetotaldecimal=$(printf "%03d" ${#video_file_list[@]}) #converting filescount to a 3 decimal output

        for file_path in "${video_file_list[@]}"; do

            # highlight_episode
            highlighted_episode=$(highlight_episode "$file_path")

            filecountdecimal=$(printf "%03d" $filecount)
            echo "────────────────────────────────────────────────────────────────"
            echo -e "${WHITE_ON_GRAY} ""$filecountdecimal""|""$filetotaldecimal"" ${NC} Merging: $highlighted_episode${NC}"
            echo "────────────────────────────────────────────────────────────────"
            ((filecount++))
            output_path="$output_folder/$(basename "$file_path")"
            apply_mkvmerge_on_file "$file_path" "$output_path"
        done
    fi

    _exit 0
}



check_dependecies(){

    # Error check: Input path is invalid
    if [ ! -e "$input_folder" ]; then
        _exit 1 "Input path is invalid!"
    fi

    # Error check: Output path is invalid and cannot be created
    if [ ! -e "$output_folder" ]; then
        # try to create the path
        mkdir -p "$output_folder" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            #echo "Output path is invalid or cannot be created!"
            _exit 1 "Output path is invalid or cannot be created!"
        fi
    fi

    # Error check: Input and Output paths must not be identical
    if [[ "$input_folder" == "$output_folder" ]]; then
        _exit 1 "Input and Output paths must not be identical!"
    fi

    if ! test -x "$ffprobe_path"; then
        _exit 1 "ffprobe is not installed. Please install it before running this script."
    fi

    # Error check: Videos.json file not found
    if [ ! -e "$jsonfile_path" ]; then
        _exit 1 "Videos.json file not found!"
    fi

    # Error check: mkvmerge not found
    if [ "$mkvmerge" = "binary" ]; then
        if ! test -x "$mkvmerge_path"; then
            _exit 1 "mkvmerge not found!"
        fi
    elif [ "$mkvmerge" = "flatpak" ]; then
        if ! test -x "/var/lib/flatpak/app/org.bunkus.mkvtoolnix-gui"; then
            _exit 1 "mkvmerge not found!"
        fi
    else
        if ! test -x "$mkvmerge_path"; then
            _exit 1 "mkvmerge not found!"
        fi
    fi
}

init() {

    mapfile -t json_array < <(jq -r '.[]' "$jsonfile_path")

    #loop over indices of bash array
    for index in "${!json_array[@]}";do
        #get item on current position
        item="${json_array[$index]}"

        #if current position has value --output the next index is the output path
        if [[ "$item" == "--output" ]]; then
            outputpath_index=$(($index + 1))
        fi

        #if current position has value ( the next index is the input path (hopefully)
        if [[ "$item" == "(" ]]; then
            inputpath_index=$(($index + 1))
        fi
    done

    #if one path is not found: invalid json
    if [[ $outputpath_index -eq -1 || $inputpath_index -eq -1 ]]; then
        _exit 1 "there is an error with the json config file: input or output path not found"
    fi

    #save all mp4 and mkv file paths in video_file_list array
    mapfile -t video_file_list < <(find "$input_folder" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" \) | sort)

    if [ "${#json_array[@]}" -eq 0 ]; then
        _exit 1 "no files found in $input_folder"
    fi

}


get_user_variables_from_ini_file() {

    # get absolut path of the ini file
    settings_file=$(relativ_to_fullpath "$settings_file")

    # abort script if settings file can't be found
    if [ ! -e "$settings_file" ]; then
        _exit 1 "Settingsfile not found at: "$settings_file
    fi

    # read ini values
    input_folder=$(sed -nr "/^\[pathes\]/ { :l /^input_folder[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    output_folder=$(sed -nr "/^\[pathes\]/ { :l /^output_folder[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    jsonfile_path=$(sed -nr "/^\[pathes\]/ { :l /^jsonfile_path[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    mode=$(sed -nr "/^\[mode\]/ { :l /^mode[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    mkvmerge=$(sed -nr "/^\[mkvmerge\]/ { :l /^mkvmerge[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    notification_text=$(sed -nr "/^\[notification_text\]/ { :l /^notification_text[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")
    nofification_audio=$(sed -nr "/^\[nofification_audio\]/ { :l /^nofification_audio[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$settings_file")


   
}

check_credibility(){

    local global_error=false
    local file_error=false
    local first_iteration_audio_language_array=()
    local first_iteration_subtitle_language_array=()
    local files=("$@")
    local filetotaldecimal=$(printf "%03d" ${#files[@]}) #converting filescount to a 3 decimal output 
    local filecount=1 #count variable for the echo output
    local filecountdecimal="" #same count variable in 3 decimal 
    local audio_language_array_sep=""
    local subtitle_language_array_sep=""
    local seperator="|"


    echo -e "${BLACK_ON_WHITE}                      Checking credibility                      ${NC}"
    echo "────────────────────────────────────────────────────────────────"

    for file in "${files[@]}"; do

        ffprobe_json=$("$ffprobe_path" -v error -show_streams -of json "$file")

        # Run ffprobe and extract language information using jq, store it in a bash array
        readarray -t audio_language_array < <(echo "$ffprobe_json" | jq '.streams[] | select(.codec_type == "audio") | .tags.language')
        readarray -t subtitle_language_array < <(echo "$ffprobe_json" | jq '.streams[] | select(.codec_type == "subtitle") | .tags.language')

        # Debug Print the contents of the array
        #printf '%s\n' "${language_array[@]}"

        if [[ $filecount = 1 ]]; then
            first_iteration_audio_language_array=("${audio_language_array[@]}")
            first_iteration_subtitle_language_array=("${subtitle_language_array[@]}")
        elif [[ "${first_iteration_audio_language_array[*]}" != "${audio_language_array[*]}" || "${first_iteration_subtitle_language_array[*]}" != "${subtitle_language_array[*]}" ]]; then
            global_error=true
            file_error=true
        fi

        #converting filecount to a 3 decimal output 
        filecountdecimal=$(printf "%03d" $filecount)


        #converadding seperator to audio_language_array ($seperator)
        audio_language_array_sep=$(printf "%s$seperator" "${audio_language_array[@]}")
        #cutting off last seperator
        audio_language_array_sep=${audio_language_array_sep%$seperator}

        #adding seperator to subtitle_language_array ($seperator)
        subtitle_language_array_sep=$(printf "%s$seperator" "${subtitle_language_array[@]}")
        #cutting last off seperator
        subtitle_language_array_sep=${subtitle_language_array_sep%$seperator}

        # highlight_episode
        highlighted_episode=$(highlight_episode "$file")

        if [ $file_error = true ]; then
            echo -e "${WHITE_ON_GRAY} ""$filecountdecimal""|""$filetotaldecimal"" ${NC} ${RED}Audio: ${#audio_language_array[@]} [${audio_language_array_sep[*]}]${NC} ${WHITE_ON_GRAY}|${NC} ${RED}Subtitle: ${#subtitle_language_array[@]} [${subtitle_language_array_sep[*]}]${NC} $highlighted_episode${NC}"
        else
            echo -e "${WHITE_ON_GRAY} ""$filecountdecimal""|""$filetotaldecimal"" ${NC} ${GREEN}Audio: ${#audio_language_array[@]} [${audio_language_array_sep[*]}]${NC} ${WHITE_ON_GRAY}|${NC} ${GREEN}Subtitle: ${#subtitle_language_array[@]} [${subtitle_language_array_sep[*]}]${NC} $highlighted_episode${NC}"
        fi

        ((filecount++))

        file_error=false

    done

    if [ $global_error = true ]; then
        #echo "────────────────────────────────────────────────────────────────"
        #echo -e "${WHITE_ON_RED}     The credibility check returned with errors! Aborting...    ${NC}"
        #echo "────────────────────────────────────────────────────────────────"
        _exit 1 "The credibility check returned with errors! Aborting"
    else
        echo "────────────────────────────────────────────────────────────────"
        echo -e "${BLACK_ON_WHITE}               The credibility test went smoothly               ${NC}"
        echo "────────────────────────────────────────────────────────────────"
    fi
}


# MKV Merge Batch Function
apply_mkvmerge_on_file() {
    #parameter is path of a video file to be merged
    local input_file=$1
    local output_file=$2
    local command="$mkvmerge_path"

    #update input path in video json array
    json_array[inputpath_index]="$input_file"

    #update output path in video json array
    json_array[outputpath_index]="$output_file"

    for argument in "${json_array[@]}"; do
        command+=" \"$argument\""
    done

    eval "$command"

}

#beep sounds via speaker-test
playsound_speaker_sound() {
  (
    \speaker-test --frequency $1 --test sine > /dev/null 2>&1 &
    pid=$!
    \sleep 0.${2}s
    \kill -9 $pid > /dev/null 2>&1
  ) > /dev/null 2>&1
}


_exit(){

    #get the exit message
    local error_state="$1"
    local error_msg="$2"
    local scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

    #script stopted with errors
    if [ "$error_state" = 1 ]; then

        #echo output
        echo "────────────────────────────────────────────────────────────────"
        echo -e "${WHITE_ON_RED}                             Error                              ${NC}"  
        echo
        echo -e "${RED}$error_msg${NC}"
        echo "────────────────────────────────────────────────────────────────"

        #notification_text
        if [ "$notification_text" = "on" ]; then
            notify-send --urgency=critical "Auto MKVMerge Warning" "$error_msg"
        fi

        #nofification_audio
        if [ "$nofification_audio" = "beep" ]; then
            playsound_speaker_sound 1500 150
            playsound_speaker_sound 1500 150
            playsound_speaker_sound 1500 150
        elif [ "$nofification_audio" = "voice" ]; then
            spd-say "Auto MKVMerge Error"
        elif [ "$nofification_audio" = "file" ]; then
            aplay "$scriptpath/error.wav" > /dev/null 2>&1
        fi

        #exit the script
        echo
        read -n 1 -s -r -p "Press any key to exit"
        exit

    fi

    #normal exit
    if [ "$error_state" = 0 ]; then

        #echo output
        echo "────────────────────────────────────────────────────────────────"
        echo -e "${BLACK_ON_WHITE}                           Finished!                            ${NC}"        
        echo "────────────────────────────────────────────────────────────────"

        #notification_text
        if [ "$notification_text" = "on" ]; then
            notify-send --urgency=normal "Auto MKVMerge" "Finished!"
        fi

        #nofification_audio
        if [ "$nofification_audio" = "beep" ]; then
            playsound_speaker_sound 200 200
            playsound_speaker_sound 400 200
        elif [ "$nofification_audio" = "voice" ]; then
            spd-say "Auto MKVMerge ist fertig"
        elif [ "$nofification_audio" = "file" ]; then
            aplay "$scriptpath/done.wav" > /dev/null 2>&1
        fi

        #exit the script
        echo
        read -n 1 -s -r -p "Press any key to exit"
        exit

    fi

    #exit the script
    echo
    read -n 1 -s -r -p "Press any key to exit"
    exit

}


# coloring SxxExx in string
highlight_episode() {
    local input="$1"
    local normal_color=${NC}
    local episode_color=${BLUE}
    
    local highlighted_episode=$(echo "$input" | awk -v normal_color="$normal_color" -v episode_color="$episode_color" 'BEGIN { IGNORECASE=1 } { gsub(/s[0-9]{2}e[0-9]{2}([e][0-9]{2})?/, episode_color"&\033[0m", $0); print normal_color$0"\033[0m" }')
    
    echo "$highlighted_episode"
}


relativ_to_fullpath() {

    local path="$1"
    scriptpath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    
    if [ ! -e "$path" ]; then
        pathfull=$(realpath "$(dirname "$scriptpath")/$path")
    else
        pathfull=$path
    fi

    echo "$pathfull"

}




# Main
main


$SHELL
