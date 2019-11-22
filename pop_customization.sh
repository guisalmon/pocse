#!/bin/bash

resDir="res"
colorCodes="$resDir/colorCodes"
refDir=""
modDir=""
modPrefix=".modified_"
exportDir=""
userPrefix="Pop-"
colorsJson="$resDir/colors.json"
shellColors="/gnome-shell/src/gnome-shell-sass/_colors.scss"
popOsColors="/gnome-shell/src/gnome-shell-sass/_pop_os_colors.scss"
gtkShellColors="/gtk/src/light/gtk-3.20/_colors.scss"
gtkPopOsColors="/gtk/src/light/gtk-3.20/_pop_os-colors.scss"

# Functions related to color output in terminal if -c option was provided

hexToRGB () {
	hex=$1
	printf "%d %d %d\n" 0x${hex:0:2} 0x${hex:2:2} 0x${hex:4:2}
}

getClosestColor () {
	ir=$1
	ig=$2
	ib=$3
	colors=`cat $colorsJson`
    max=`echo $colors | jq '. | length'`
	minOffset=765 #3x255
	declare -A colorArray
	for (( i=0; i<$max; i++ ))
	do	
		color=`echo $colors | jq ".[$i]"`
		r=`echo $color | jq ".rgb.r"`
		g=`echo $color | jq ".rgb.g"`
		b=`echo $color | jq ".rgb.b"`
		offsetR=$((ir-r))
		offsetG=$((ig-g))
		offsetB=$((ib-b))

		[ $offsetR -lt 0 ] && offsetR=$((0-offsetR))
		[ $offsetG -lt 0 ] && offsetG=$((0-offsetG))
		[ $offsetB -lt 0 ] && offsetB=$((0-offsetB))

		offset=$((offsetR+offsetG+offsetB))

		if [ $offset -le $minOffset ]
		then
			if [ ${colorArray[$offset]+_} ] 
			then colorArray["$offset"]+=", $color"
			else colorArray["$offset"]=$color
			fi
			minOffset=$offset
		fi
	done
	echo ${colorArray["$minOffset"]} | jq '.'
}

colorCodeCached () {
	code="-1"
	while read l ; do
		line=($l)
		[ $1 == ${line[0]} ] && code=${line[1]}
	done < $colorCodes
	echo $code
}

getColorCode () {
	hex=$1
	code=0
	if [[ ${#hex} -eq 7 ]]
	then
		hex="${hex:1}"
		if [[ $hex =~ ^[0-9A-Fa-f]{6}$ ]]
		then
			touch $colorCodes
			code=`colorCodeCached $hex`
			if [ $code == "-1" ] 
			then
				rgb=(`hexToRGB $hex`)
				r=${rgb[0]}
				g=${rgb[1]}
				b=${rgb[2]}
				color=`getClosestColor $r $g $b`
				code=`echo $color | jq ".colorId"`
				echo "$hex $code" >> $colorCodes
			fi
		fi
	fi
    echo $code
}

# end of color output related functions

# Script parameters handling

manHeader='Usage: pop_customization [OPTIONS] [DIRECTORY] \nGenerates a Pop OS based theme with a custom color scheme.\n'
man='\n -d \t Force download of reference theme from Pop OS git repo.
\n -i \t Install theme after customization
\n -r \t Reset installed theme to vanilla Pop OS theme.
\n -h \t Display this help and exit.
\n -c \t Use terminal colors for preview (compatible with most modern terminals)
\n -e \t Edit theme after parsing of colors
\n -u [DIRECTORY] \t Update a previously edited theme
\n -o NAME \t Specify a name for the new theme'

d=false
i=false
r=false
c=false
e=false
u=false
o=false
lastArg=""
for arg in "$@"
do
	case $arg in
	"-d")
		d=true
		;;
	"-i")
		i=true
		;;
	"-r")
		echo "-r isn't yet implemented"
		r=true
		exit
		;;
	"-h")
		echo -e $manHeader
		echo -e $man | column -ts $'\t'
		exit
		;;
	"-c")
		c=true
		;;
	"-e")
		e=true
		;;
	"-u")
		u=true
		;;
	"-o")
		o=true
		;;
	*)
		case $lastArg in 
		"-u")
			if [[ $arg != "" && -d $arg && -f $arg$shellColors && -f $arg$gtkShellColors && -f $arg$popOsColors && -f $arg$gtkPopOsColors ]]
			then
				refDir=$arg
			else
				echo "$arg is not a valid theme directory"
				exit
			fi
			;;
		"-o")
			if [[ $arg != "" ]]
			then
				modDir=$modPrefix$userPrefix$arg
				exportDir=$userPrefix$arg
			else exit
			fi
			;;
		*)
			echo "Unknown argument $arg"
			exit
		;;
		esac
	esac
	lastArg=$arg
done

$o && [[ $modDir == "" ]] && exit

if $u
then
	if $d 
	then
		echo -e "-d and -u options cannot be used together. \nIt is not possible to both use the theme from Pop OS git repo and an a previously edited theme as reference."
		exit
	fi
	if [[ $refDir == "" || ! -d $refDir ]]
	then
		echo "Please provide a valid theme directory as reference to update : "
		input=""
		while [[ $input == "" || ! -d $input || ! -f $input$shellColors || ! -f $input$gtkShellColors || ! -f $input$popOsColors || ! -f $input$gtkPopOsColors ]]
		do
			echo -ne "$userPrefix"
			read input
			input=$userPrefix$input
		done
		refDir=$input
	fi
else
	refDir="Pop_Reference"
fi

[ ! -d $resDir ] && mkdir $resDir

if ! $d
then
	if [ ! -d $refDir ]
	then 
		echo "Reference theme not locally available, do you want to download it? [Y/n]"
		read input
		case $input in
		"y"|"yes"|""|"Yes"|"Y")
			d=true
			;;
		*)
			exit
			;;
		esac
	fi
fi

if $d 
then
	echo "Get official Pop OS theme from git repo." 
	rm -r $refDir
	git clone https://github.com/pop-os/gtk-theme.git $refDir
fi

if $c
then
	echo -e "\n\033[01;01mDisclaimer : \033[00m"
	echo -e "\033[01;01mMost terminals have only 256 colors\033[00m"
	echo -e "\033[01;01mYour screen has more (I hope for you)\033[00m"
	echo -e "\033[01;01mColors displayed here will only be an approximation\033[00m\n"
	echo -e "\033[01;01mParsing TermX color codes will take a while on the first run, but once cached it'll be faster on subsequent runs\033[00m\n"
	if ! [ -f $colorsJson ]
	then
		echo "Reference color codes not locally available, do you want to download them? [Y/n]"
		read input
		case $input in
		"y"|"yes"|""|"Yes"|"Y")
			curl https://jonasjacek.github.io/colors/data.json | jq . > $colorsJson
			;;
		*)
			echo "Won't use colors"
			c=false
			;;
		esac
	fi
fi

# End of script parameter handling

count=0
while read l; do
	((count++))
	print=false
	dark=false
	case $l in
	*"- Orange:"*)
		color="Orange: "
		;;
	*"- Blue:"*)
		color="Blue: "
		;;
	*"- Window background:"*)
		color="Window Background: "
		;;
	*"- Header/Title Bars:"*)
		color="Header/Title Bars: "
		;;
	*"- Dark theme:"*)
		dark=true
		words=($l)
		#echo "color 1: ${words[3]}, color 2: ${words[5]}"
		;;
	*"- Light theme:"*)
		words=($l)
		#echo "color 1: ${words[3]}, color 2: ${words[5]}"
		;;
	esac
done < $refDir/TESTING.md

if $c
then echo -e "\033[01;01mLet's extract colors used in gnome-shell Pop OS theme\033[00m\n"
else echo -e "Let's extract colors used in gnome-shell Pop OS theme\n"
fi

declare -A gnomeColorMap
declare -a gnomeColorList
gnomeColorIndex=0
placeholder="."

formatHex () {
	li=${1#*#}
	echo "#${li:0:6}"
}

# Parsing colors from /gnome-shell/src/gnome-shell-sass/_colors.scss 

baseColorsArray=("\$base_color" "\$bg_color" "\$fg_color")

while read l; do
	words=($l)
	for color in ${baseColorsArray[*]}
	do
		if [[ $l == *"$color:"* ]]
		then
			gnomeColorList[$gnomeColorIndex]=$color
			(( gnomeColorIndex++ ))
			gnomeColorMap[$color,0]=`formatHex ${words[4]}`
			gnomeColorMap[$color,1]=`formatHex ${words[5]}`
		fi
	done
done < $refDir$shellColors

# End of color parsing from /gnome-shell/src/gnome-shell-sass/_colors.scss 

# Parsing colors from /gnome-shell/src/gnome-shell-sass/_pop_os_colors.scss 

popColorsArray=("orange" "blue" "green" "red" "yellow" "purple" "pink" "indigo")
variants=("\$" "\$highlights_" "\$text_")
uiColorsArray=("_ui_100" "_ui_300" "_ui_500" "_ui_700" "_ui_900")

extractPopColors () {
	words=($1)
	for color in ${popColorsArray[*]}
	do
		for variant in ${variants[*]}
		do
			if [[ $1 == *"$variant$color"* ]]
			then
				gnomeColorList[$gnomeColorIndex]=$variant$color
				(( gnomeColorIndex++ ))
				gnomeColorMap[$variant$color,0]=`formatHex ${words[2]}`
				gnomeColorMap[$variant$color,1]=`formatHex ${words[3]}`
			fi
		done
	done
}

extractWarmGreys () {
	words=($1)
	case $1 in
	*"\$light_warm_grey:"*)
		gnomeColorList[$gnomeColorIndex]="\$light_warm_grey"
		(( gnomeColorIndex++ ))
		gnomeColorMap["\$light_warm_grey",2]=`formatHex ${words[1]}`
		;;
	*"\$dark_warm_grey:"*)
		gnomeColorList[$gnomeColorIndex]="\$dark_warm_grey"
		(( gnomeColorIndex++ ))
		gnomeColorMap["\$dark_warm_grey",2]=`formatHex ${words[1]}`
		;;
	*"\$warm_grey:"*)
		gnomeColorList[$gnomeColorIndex]="\$warm_grey"
		(( gnomeColorIndex++ ))
		gnomeColorMap["\$warm_grey",2]=`formatHex ${words[1]}`
		;;
	esac
}

extractUIColors () {
	words=($1)
	for color in ${uiColorsArray[*]}
	do
		if [[ $1 == *"\$light$color:"* ]]
		then
			gnomeColorList[$gnomeColorIndex]="\$light$color"
			(( gnomeColorIndex++ ))
			gnomeColorMap["\$light$color",2]=`formatHex ${words[1]}`
		fi
		if [[ $1 == *"\$dark$color:"* ]]
		then
			gnomeColorList[$gnomeColorIndex]="\$dark$color"
			(( gnomeColorIndex++ ))
			gnomeColorMap["\$dark$color",2]=`formatHex ${words[1]}`
		fi
	done
}

extractGDMGrey () {
	words=($1)
	if [[ $1 == *"\$gdm_grey:"* ]]
	then
		gnomeColorList[$gnomeColorIndex]="\$gdm_grey"
		(( gnomeColorIndex++ ))
		gnomeColorMap["\$gdm_grey",2]=`formatHex ${words[1]}`
	fi
}

while read l || [ -n "$l" ]
do
	extractPopColors "$l" 
	extractWarmGreys "$l"
	extractUIColors "$l"
	extractGDMGrey "$l"
done < $refDir$popOsColors

# End of color parsing from /gnome-shell/src/gnome-shell-sass/_pop_os_colors.scss 

# Display colors parsed from reference gnome-shell theme

formatColor () {
	if $c
	then
		if [[ ${#1} -eq 7 && ${1:1} =~ ^[0-9A-Fa-f]{6}$ ]]
		then 
			color="\033[01;38;5;`getColorCode $1`m$1\033[00m"
		else 
			color="\033[00;08m$placeholder\033[00m"
		fi
	else
		if [[ ${#1} -eq 7 && ${1:1} =~ ^[0-9A-Fa-f]{6}$ ]]
		then 
			color=$1
		else 
			color="$placeholder"
		fi
	fi
	echo $color
}

formatColors () {
	echo "$1 `formatColor $2` `formatColor $3` `formatColor $4`"
}

display () {
	echo -e 'Colors Light Dark Neutral'
	declare -a validColors	
	size=${#gnomeColorMap[@]}
	count=0
	for color in ${gnomeColorList[*]} 
	do
		for i in {0..2}
		do
			if [[ ${#gnomeColorMap[$color,$i]} -eq 7 && ${gnomeColorMap[$color,$i]:1} =~ ^[0-9A-Fa-f]{6}$ ]]
			then 
				validColors[$i]=${gnomeColorMap[$color,$i]}
				(( count++ ))
			else 
				validColors[$i]=$placeholder
			fi
		done
		echo -ne "Parsing pop color code $count of $size"\\r 1>&2
		echo -e `formatColors "$color" "${validColors[0]}" "${validColors[1]}" "${validColors[2]}"`
	done 
}

display | column -t

# Done displaying parsed colors

if $c
then echo -e "\n\033[01;01mNow let's extract colors used in gtk Pop OS theme and display only those different from gnome theme\033[00m\n"
else echo -e "\nNow let's extract colors used in gtk Pop OS theme and display only those different from gnome theme\n"
fi

declare -A gtkColorMap
declare -a gtkColorList
gtkColorIndex=0

# Parsing colors from /gtk/src/light/gtk-3.20/_colors.scss

extractGTKBaseColors () {
	words=($1)
	for color in ${baseColorsArray[*]}
	do
		if [[ $1 == *"$color:"* ]]
		then
			gtkColorList[$gtkColorIndex]=$color
			(( gtkColorIndex++ ))
			gtkColorMap[$color,0]=`formatHex ${words[4]}`
			gtkColorMap[$color,1]=`formatHex ${words[5]}`
		fi
	done
}

while read l; do
	extractGTKBaseColors "$l"
done < $refDir$gtkShellColors

# End of color parsing from /gtk/src/light/gtk-3.20/_colors.scss

# Parsing colors from /gtk/src/light/gtk-3.20/_pop_os-colors.scss

gtkExtractPopColors () {
	words=($1)
	for color in ${popColorsArray[*]}
	do
		for variant in ${variants[*]}
		do
			if [[ $1 == *"$variant$color"* && $1 != *"//"* ]]
			then
				gtkColorList[$gtkColorIndex]=$variant$color
				(( gtkColorIndex++ ))
				gtkColorMap[$variant$color,0]=`formatHex ${words[2]}`
				gtkColorMap[$variant$color,1]=`formatHex ${words[3]}`
			fi
		done
	done
}

gtkExtractWarmGreys () {
	words=($1)
	case $1 in
	*"\$light_warm_grey:"*)
		gtkColorList[$gtkColorIndex]="\$light_warm_grey"
		(( gtkColorIndex++ ))
		gtkColorMap["\$light_warm_grey",2]=`formatHex ${words[1]}`
		;;
	*"\$dark_warm_grey:"*)
		gtkColorList[$gtkColorIndex]="\$dark_warm_grey"
		(( gtkColorIndex++ ))
		gtkColorMap["\$dark_warm_grey",2]=`formatHex ${words[1]}`
		;;
	*"\$warm_grey:"*)
		gtkColorList[$gtkColorIndex]="\$warm_grey"
		(( gtkColorIndex++ ))
		gtkColorMap["\$warm_grey",2]=`formatHex ${words[1]}`
		;;
	esac
}

gtkExtractUIColors () {
	words=($1)
	for color in ${uiColorsArray[*]}
	do
		if [[ $1 == *"\$light$color:"* ]]
		then
			gtkColorList[$gtkColorIndex]="\$light$color"
			(( gtkColorIndex++ ))
			gtkColorMap["\$light$color",2]=`formatHex ${words[1]}`
		fi
		if [[ $1 == *"\$dark$color:"* ]]
		then
			gtkColorList[$gtkColorIndex]="\$dark$color"
			(( gtkColorIndex++ ))
			gtkColorMap["\$dark$color",2]=`formatHex ${words[1]}`
		fi
	done
}

gtkExtractGDMGrey () {
	words=($1)
	if [[ $1 == *"\$gdm_grey:"* ]]
	then
		gtkColorList[$gnomeColorIndex]="\$gdm_grey"
		(( gtkColorIndex++ ))
		gtkColorMap["\$gdm_grey",2]=`formatHex ${words[1]}`
	fi
}

while read l || [ -n "$l" ]
do
	gtkExtractPopColors "$l" 
	gtkExtractWarmGreys "$l"
	gtkExtractUIColors "$l"
	gtkExtractGDMGrey "$l"
done < $refDir$gtkPopOsColors

# End of color parsing from /gtk/src/light/gtk-3.20/_pop_os-colors.scss

# Display colors parsed from reference gtk theme

displayGTK () {
	echo -e 'Colors Light Dark Neutral'
	declare -a validColors	
	size=${#gtkColorMap[@]}
	count=0
	for color in ${gtkColorList[*]} 
	do
		for i in {0..2}
		do
			if [[ ${#gtkColorMap[$color,$i]} -eq 7 && ${gtkColorMap[$color,$i]:1} =~ ^[0-9A-Fa-f]{6}$ && ${gtkColorMap[$color,$i]} != ${gnomeColorMap[$color,$i]} ]]
			then 
				validColors[$i]=${gtkColorMap[$color,$i]}
				(( count++ ))
			else 
				validColors[$i]=$placeholder
			fi
		done
		echo -ne "Parsing pop color code $count of $size"\\r 1>&2
		echo -e `formatColors "$color" "${validColors[0]}" "${validColors[1]}" "${validColors[2]}"`
	done 
}

displayGTK | column -t

# Done displaying parsed colors

if ! $e
then
	echo -e "\n"
	echo -e "Do you want to edit the theme? [Y/n]"
	read input
	case $input in
	"y"|"yes"|""|"Yes"|"Y")
		e=true
		;;
	*)
		exit
		;;
	esac
fi

if ! $o
then
	echo -e "How will you name your theme (cannot be empty)? \nIf you already defined a variant with this name, it will be overwritten." 
	input=""
	while [[ $input == "" ]]
	do
		echo -ne "$userPrefix"
		read input
	done
	modDir=$modPrefix$userPrefix$input
	exportDir=$userPrefix$input
fi
[ -d $modDir ] && rm -r $modDir
cp -r $refDir $modDir
echo -e "\nReference theme directory copied to $modDir where modifications will happen.\n"

# Edit parsed colors

input=""
while [[ $input != "l" && $input != "d" ]]
do
	echo -ne "Edit [l]ight or [d]ark variant (later on you'll have the opportunity to mess up the other variant too): "
	read input
done

[[ $input == "l" ]] && variant=0 || variant=1

input=""
while [[ $input != "m" && $input != "a" ]]
do
	echo -ne "Edit only [m]ain colors or [a]ll color: "
	read input
done

[[ $input == 'm' ]] && quick=true || quick=false

if ! $quick
then
	echo "Edition of all colors not implemented yet, fallback to quick edition"
	quick=true
fi

newColorArray=("\$orange" "\$highlights_orange" "\$text_orange" "\$blue" "\$highlights_blue" "\$text_blue")
declare -a editedColorArray
editedColorIndex=0
declare -A gnomeNewColorMap

echo -e "\nYou will be prompted with colors to edit, type in valid hexadecimal color codes (eg. #000000) to edit them or [ENTER] to keep them\n"

gnomeGetUserInput () {
	input="."
	while ! [[ ${#input} -eq 7 && ${input:1} =~ ^[0-9A-Fa-f]{6}$ || $input == "" ]]
	do
		echo -ne "$1: `formatColor ${gnomeColorMap[$1,$variant]}` : "
		read input
	done
	if [[ $input != "" ]]
	then
		gnomeNewColorMap[$1,$variant]=$input
		editedColorArray[$editedColorIndex]=$1
		(( editedColorIndex++ ))
	fi
}

for color in ${newColorArray[*]}
do
	gnomeGetUserInput $color
done

[[ $variant == 0 ]] && variantName="light" || variantName="dark"
[[ $variant == 0 ]] && newVariantName="dark" || newVariantName="light"

input="."
while [[ $input != "y" && $input != "Y" && $input != "n" && $input != "N" && $input != "yes" && $input != "Yes" && $input != "no" && $input != "No" && $input != "" ]]
do
	echo -ne "Do you want to edit $newVariantName theme? [Y/n]"
	read input
done

case $input in
	"y"|"yes"|""|"Yes"|"Y")
		edit=true
		;;
	*)
		edit=false
		;;
esac

if $edit
then
	oldVariant=$variant
	[[ $variant  == 0 ]] && variant=1 || variant=0

	input="."
	while [[ $input != "y" && $input != "Y" && $input != "n" && $input != "N" && $input != "yes" && $input != "Yes" && $input != "no" && $input != "No" && $input != "" ]]
	do
		echo -ne "Do you want to reuse colors from $variantName theme in $newVariantName theme where they were reused in reference theme? [Y/n]"
		read input
	done
	case $input in
		"y"|"yes"|""|"Yes"|"Y")
			reuse=true
			;;
		*)
			reuse=false
			;;
	esac

	if $reuse
	then
		for color in ${editedColorArray[*]}
		do
			for otherColor in ${newColorArray[*]}
			do
				if [[ ${gnomeColorMap[$color,$oldVariant]} == ${gnomeColorMap[$otherColor,$variant]} ]]
				then
					if [[ ${#gnomeNewColorMap[$otherColor,0]} -ne 7 
						&& ! ${gnomeNewColorMap[$otherColor,0]:1} =~ ^[0-9A-Fa-f]{6}$ 
						&& ${#gnomeNewColorMap[$otherColor,1]} -ne 7 
						&& ! ${gnomeNewColorMap[$otherColor,1]:1} =~ ^[0-9A-Fa-f]{6}$ 
						&& ${#gnomeNewColorMap[$otherColor,2]} -ne 7 
						&& ! ${gnomeNewColorMap[$otherColor,2]:1} =~ ^[0-9A-Fa-f]{6}$ ]]
					then
						editedColorArray[$editedColorIndex]=$otherColor
						(( editedColorIndex++ ))
					fi
					blbl=${gnomeNewColorMap[$color,$oldVariant]}
					gnomeNewColorMap[$otherColor,$variant]=$blbl
				fi
			done
		done
	fi

	for color in ${editedColorArray[*]}
	do 
		if [[ ${#gnomeNewColorMap[$color,$variant]} -ne 7 
			&& ! ${gnomeNewColorMap[$color,$variant]:1} =~ ^[0-9A-Fa-f]{6}$ ]]
		then
			gnomeGetUserInput $color
		fi
	done
fi

editionFormatColors () {
	echo "$1 `formatColor $2` `formatColor $3` `formatColor $4` `formatColor $5` `formatColor $6` `formatColor $7`"
}

displayEdition () {
	echo -e 'Edited Light New Dark New Neutral Neutral'
	declare -a validColors	
	size=${#gnomeNewColorMap[@]}
	count=0
	for color in ${editedColorArray[*]} 
	do
		for i in {0..2}
		do
			if [[ ${#gnomeNewColorMap[$color,$i]} -eq 7 && ${gnomeNewColorMap[$color,$i]:1} =~ ^[0-9A-Fa-f]{6}$ ]]
			then 
				validColors[$i]=${gnomeNewColorMap[$color,$i]}
				(( count++ ))
			else 
				validColors[$i]=$placeholder
			fi
		done
		echo -ne "Parsing color code $count of $size"\\r 1>&2
		echo -e `editionFormatColors "$color" "${gnomeColorMap[$color,0]}" "${validColors[0]}" "${gnomeColorMap[$color,1]}" "${validColors[1]}" "${gnomeColorMap[$color,2]}" "${validColors[2]}"`
	done 
}

echo -e "\n"
displayEdition | column -t
