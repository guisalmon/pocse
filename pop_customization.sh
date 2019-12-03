#!/bin/bash

resDir="res"
colorCodes="$resDir/colorCodes"
userColorCodes="$resDir/userColorCodes"
refDir=""
modDir=""
modPrefix=".modified_"
lastTheme=".last"
exportDir=""
userPrefix="Pop-"
colorsJson="$resDir/colors.json"
shellColors="/gnome-shell/src/gnome-shell-sass/_colors.scss"
popOsColors="/gnome-shell/src/gnome-shell-sass/_pop_os_colors.scss"
gtkColors="/gtk/src/light/gtk-3.20/_colors.scss"
gtkPopOsColors="/gtk/src/light/gtk-3.20/_pop_os-colors.scss"
gtkUbuntuColors="/gtk/src/light/gtk-3.20/_ubuntu-colors.scss"
gtkTweaks="/gtk/src/light/gtk-3.20/_tweaks.scss"
colorExportsDir="color_exports"

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
			[ ${colorArray[$offset]+_} ] && colorArray["$offset"]+=", $color" || colorArray["$offset"]=$color
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
	done < $userColorCodes
	echo $code
}

getColorCode () {
	hex=$1
	code=37
	fgCode=97
	if [[ ${#hex} -eq 7 ]]
	then
		hex="${hex:1}"
		if [[ $hex =~ ^[0-9A-Fa-f]{6}$ ]]
		then
			rgb=(`hexToRGB $hex`)
			rgbSum=$((${rgb[0]}+${rgb[1]}+${rgb[2]}))
			[[ $rgbSum -le 382 ]] && fgCode="97" || fgCode="30"
			[[ ! -f $userColorCodes ]] && cp $colorCodes $userColorCodes
			code=`colorCodeCached $hex`
			if [ $code == "-1" ] 
			then
				color=`getClosestColor ${rgb[0]} ${rgb[1]} ${rgb[2]}`
				code=`echo $color | jq ".colorId"`
				echo "$hex $code" >> $userColorCodes
			fi
		fi
	fi
    echo "$fgCode;48;5;$code"
}

# end of color output related functions

# Script parameters handling

manHeader='Usage: pop_customization [OPTIONS] \nGenerates a Pop OS based theme with a custom color scheme.\n'
man="\n -d \t Force download of reference theme from Pop OS git repo.
\n -i \t Install theme after customization
\n -r \t Reset installed theme to vanilla Pop OS theme.
\n -h \t Display this help and exit.
\n -c \t Use terminal colors for preview (compatible with most modern terminals)
\n -e \t Edit theme after parsing of colors
\n -u [DIRECTORY] \t Update a previously edited theme
\n -o NAME \t Specify a name for the new theme
\n -s FILE \t Use a previously exported scheme from $colorExportsDir instead of manually edit colors"

installTheme () {
	cd $exportDir
	meson build && cd build
	ninja
	ninja install
	cd ../../
	touch $lastTheme
	echo $exportDir > $lastTheme
	echo -e "\nDon't forget to select your newly installed theme from the Gnome tweak tool"
	echo "It is also recommanded that you restart the shell, either by login out then in or by typing alt-f2 then r"
}

d=false
install=false
r=false
c=false
e=false
u=false
o=false
declare -A importedGnomeScheme
declare -A importedGTKScheme
lastArg=""
for arg in "$@"
do
	case $arg in
	"-d")
		d=true
		;;
	"-i")
		install=true
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
	"-s")
		;;
	"-r")
		r=true
		;;
	*)
		case $lastArg in 
		"-u")
			if [[ $arg != "" && -d $arg && -f $arg$shellColors && -f $arg$gtkColors && -f $arg$popOsColors && -f $arg$gtkPopOsColors ]]
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
		"-s")
			if [ -f $arg ]
			then
				themeType=""
				while read l || [ -n "$l" ] ; do
					words=($l)
					if [[ ${#words[@]} == 1 ]]
					then
						themeType=${words[0]}
					elif [[ ${#words[@]} == 4 && ${words[0]} = \$* ]]
					then
						if [[ $themeType = "Gnome" ]]
						then
							importedGnomeScheme[${words[0]},0]=${words[1]}
							importedGnomeScheme[${words[0]},1]=${words[2]}
							importedGnomeScheme[${words[0]},2]=${words[3]}
						elif [[ $themeType = "GTK" ]]
						then
							importedGTKScheme[${words[0]},0]=${words[1]}
							importedGTKScheme[${words[0]},1]=${words[2]}
							importedGTKScheme[${words[0]},2]=${words[3]}
						fi
					fi
				done < $arg
			else
				echo "$arg is not a file"
				exit
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
		while [[ $input == "" || ! -d $input || ! -f $input$shellColors || ! -f $input$gtkColors || ! -f $input$popOsColors || ! -f $input$gtkPopOsColors ]]
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
	if [ ! -d "Pop_Reference" ]
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

if $r
then
	if $u 
	then
		echo "Ignoring -u option, -r takes precedence"
	fi
	if ! $o
	then 
		exportDir="Pop-Reset"
		if [[ -f $lastTheme ]]
		then
			last=`cat $lastTheme`
			lastContents=($last)
			if [[ ${#lastContents[@]} == 1 ]]
			then
				exportDir=${lastContents[0]}
			fi
		fi
	fi
	echo "$exportDir will be reset to vanilla Pop OS theme"
	[[ -d $exportDir ]] && rm -r $exportDir
	cp -r "Pop_Reference" $exportDir
	sed -i "s/project('Pop'/project(\'$exportDir\'/g" "$exportDir/meson.build"
	installTheme
	exit
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

$c && echo -e "\033[01;01mLet's extract colors used in gnome-shell Pop OS theme\033[00m\n" || echo -e "Let's extract colors used in gnome-shell Pop OS theme\n"

declare -A gnomeColorMap
declare -a gnomeColorList
gnomeColorIndex=0
placeholder="."

formatHex () {
	li=${1#*#}
	echo "#${li:0:6}"
}

# Parsing colors from /gnome-shell/src/gnome-shell-sass/_colors.scss 

baseColorsArray=("\$base_color" "\$bg_color" "\$fg_color" "\$headerbar_color" "\$selected_bg_color")

while read l; do
	words=($l)
	for color in ${baseColorsArray[*]}
	do
		if [[ $l == *"$color:"* ]]
		then
			gnomeColorList[$gnomeColorIndex]=$color
			(( gnomeColorIndex++ ))
			if [[ $color == "\$selected_bg_color" ]]
			then	
				# Fix for a line formatted differently than the others in _colors.scss
				gnomeColorMap[$color,0]=`formatHex ${words[2]}`
				gnomeColorMap[$color,1]=`formatHex ${words[3]}`
			else
				gnomeColorMap[$color,0]=`formatHex ${words[4]}`
				gnomeColorMap[$color,1]=`formatHex ${words[5]}`
			fi
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
		if [[ ${1} =~ ^#[0-9A-Fa-f]{6}$ ]] 
		then color="\033[`getColorCode $1`m$1\033[00m" 
		else color="\033[00;08m$placeholder\033[00m"
		fi
	else [[ ${1} =~ ^#[0-9A-Fa-f]{6}$ ]] && color=$1 || color="$placeholder"
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
			if [[ ${gnomeColorMap[$color,$i]} =~ ^#[0-9A-Fa-f]{6}$ ]]
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
			if [[ $color == "\$selected_bg_color" ]]
			then	
				# Fix for a line formatted differently than the others in _colors.scss
				gtkColorMap[$color,0]=`formatHex ${words[2]}`
				gtkColorMap[$color,1]=`formatHex ${words[3]}`
			else
				gtkColorMap[$color,0]=`formatHex ${words[4]}`
				gtkColorMap[$color,1]=`formatHex ${words[5]}`
			fi
		fi
	done
}

while read l; do
	extractGTKBaseColors "$l"
done < $refDir$gtkColors

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
			if [[ ${gtkColorMap[$color,$i]} =~ ^#[0-9A-Fa-f]{6}$ && ${gtkColorMap[$color,$i]} != ${gnomeColorMap[$color,$i]} ]]
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
colorsFile="$colorExportsDir/${exportDir}_colors"
[[ -f $colorsFile ]] && echo "" > $colorsFile || touch $colorsFile
echo -e "\nReference theme directory copied to $modDir where modifications will happen.\n"

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

if [[ $input == 'm' ]]
then
	newColorArray=("\$orange" "\$highlights_orange" "\$text_orange" "\$blue" "\$highlights_blue" "\$text_blue" "\$base_color" "\$bg_color" "\$headerbar_color" "\$selected_bg_color" "\$gdm_grey")
else
	newColorArray=$gnomeColorList
	size=${#newColorArray[@]}
	for color in ${gtkColorList[*]}
	do
		color=${color%,*}
		if [[ ! " ${newColorArray[@]} " =~ " ${color} " ]]
		then
			newColorArray[$size]=$color
			(( size++ ))
		fi
	done
fi

# Gnome colors edition

declare -a editedColorArray
editedColorIndex=0
declare -A gnomeNewColorMap

echo -e "\nYou will be prompted with colors to edit, type in valid hexadecimal color codes (eg. #000000) to edit them or [ENTER] to keep them\n"

gnomeGetUserInput () {
	if [[ ${importedGnomeScheme[$1,$2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		input=${importedGnomeScheme[$1,$2]}
	else
		input="."
	fi
	while ! [[ ${input} =~ ^#[0-9A-Fa-f]{6}$ || $input == "" ]]
	do
		echo -ne "$1: `formatColor ${gnomeColorMap[$1,$2]}` : "
		read input
	done
	if [[ $input != "" ]]
	then
		gnomeNewColorMap[$1,$2]=$input
		if [[ ! " ${editedColorArray[@]} " =~ " ${1} " ]]
		then
			editedColorArray[$editedColorIndex]=$1
			(( editedColorIndex++ ))
		fi
	fi
}

for color in ${newColorArray[*]}
do
	if [[ ${gnomeColorMap[$color,$variant]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		gnomeGetUserInput $color $variant
	fi
	if [[ ${gnomeColorMap[$color,2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		gnomeGetUserInput $color 2
	fi
done

[[ $variant == 0 ]] && variantName="light" || variantName="dark"
[[ $variant == 0 ]] && newVariantName="dark" || newVariantName="light"

echo -e ""

input="."
while [[ ! $input =~ ^(y|Y|yes|Yes|n|N|no|No)$ && $input != "" ]]
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
	while [[ ! $input =~ ^(y|Y|yes|Yes|n|N|no|No)$ && $input != "" ]]
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

	echo -e ""

	declare -A alreadyEditedVariant

	if $reuse
	then
		for otherColor in ${newColorArray[*]}
		do
			for color in ${editedColorArray[*]}
			do
				if [[ ${gnomeColorMap[$color,$oldVariant]} == ${gnomeColorMap[$otherColor,$variant]} ]]
				then
					if [[ ! ${gnomeNewColorMap[$otherColor,0]} =~ ^#[0-9A-Fa-f]{6}$ 
						&& ! ${gnomeNewColorMap[$otherColor,1]} =~ ^#[0-9A-Fa-f]{6}$ 
						&& ! ${gnomeNewColorMap[$otherColor,2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
					then
						editedColorArray[$editedColorIndex]=$otherColor
						(( editedColorIndex++ ))
					fi
					alreadyEditedVariant[$color]=$otherColor
					gnomeNewColorMap[$otherColor,$variant]=${gnomeNewColorMap[$color,$oldVariant]}
				fi
			done
		done

	fi

	for color in ${editedColorArray[*]}
	do 
		if [[ ! ${gnomeNewColorMap[$color,$variant]} =~ ^#[0-9A-Fa-f]{6}$ 
			&& ${alreadyEditedVariant[$color]} == ""
			&& ${gnomeColorMap[$color,$variant]} =~ ^#[0-9A-Fa-f]{6}$ ]]
		then
			gnomeGetUserInput $color $variant
		fi
	done
fi

editionFormatColors () {
	echo "$1 `formatColor $2` `formatColor $3` `formatColor $4` `formatColor $5` `formatColor $6` `formatColor $7`"
}

displayEdition () {
	echo -e 'Edited Light New Dark New Neutral New'
	declare -a validColors
	colorsToFile="Gnome \nColor Light Dark Neutral \n"
	size=${#gnomeNewColorMap[@]}
	count=0
	for color in ${editedColorArray[*]} 
	do
		if [[ ${gnomeNewColorMap[$color,0]} =~ ^#[0-9A-Fa-f]{6}$ 
			|| ${gnomeNewColorMap[$color,1]} =~ ^#[0-9A-Fa-f]{6}$
			|| ${gnomeNewColorMap[$color,2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
		then
			for i in {0..2}
			do
				if [[ ${gnomeNewColorMap[$color,$i]} =~ ^#[0-9A-Fa-f]{6}$ ]]
				then 
					validColors[$i]=${gnomeNewColorMap[$color,$i]}
					(( count++ ))
				else 
					validColors[$i]=$placeholder
				fi
			done
			echo -ne "Parsing color code $count of $size"\\r 1>&2
			colorsToFile+="\n$color ${validColors[0]} ${validColors[1]} ${validColors[2]}"
			echo -e `editionFormatColors "$color" "${gnomeColorMap[$color,0]}" "${validColors[0]}" "${gnomeColorMap[$color,1]}" "${validColors[1]}" "${gnomeColorMap[$color,2]}" "${validColors[2]}"`
		fi
	done 
	echo -e $colorsToFile | column -t >> $colorsFile
}

echo -e "\n"

replaceColor () {
	if [[ ${gnomeNewColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gnomeColorMap[$1,0]},/${gnomeNewColorMap[$1,0]},/g" $modDir$popOsColors
		sed -i "s/${gnomeColorMap[$1,0]},/${gnomeNewColorMap[$1,0]},/g" $modDir$shellColors
	fi
	if [[ ${gnomeNewColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gnomeColorMap[$1,1]})/${gnomeNewColorMap[$1,1]})/g" $modDir$popOsColors
		sed -i "s/${gnomeColorMap[$1,1]})/${gnomeNewColorMap[$1,1]})/g" $modDir$shellColors
	fi
	if [[ ${gnomeNewColorMap[$1,2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gnomeColorMap[$1,2]};/${gnomeNewColorMap[$1,2]};/g" $modDir$popOsColors
	fi
}

mkdir $colorExportsDir
touch $colorsFile
echo "Modified colors in Gnome theme"
displayEdition | column -t

for color in ${editedColorArray[*]}
do
	replaceColor $color
done

# End of Gnome colors edition

# GTK colors edition

declare -a gtkEditedColorArray
gtkEditedColorIndex=0
declare -A gtkNewColorMap

variantName () {
	if [[ $1 == 0 ]] ; then echo "light" ; elif [[ $1 == 1 ]] ; then echo "dark" ; else echo "" ; fi
}

gtkGetUserInput () {
	if [[ ${importedGTKScheme[$1,$2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		input=${importedGTKScheme[$1,$2]}
	else
		input="."
	fi
	while ! [[ ${input} =~ ^#[0-9A-Fa-f]{6}$ || $input == "" ]]
	do
		if [[ ${gnomeColorMap[$1,$2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
		then
			echo -e "$1 was `formatColor ${gnomeColorMap[$1,$2]}` in Gnome, `formatColor ${gtkColorMap[$1,$2]}` in GTK"
			echo -ne "$1 was changed to `formatColor ${gnomeNewColorMap[$1,$2]}` in Gnome, enter value for GTK: "
		else
			echo -ne "$1 is `formatColor ${gtkColorMap[$1,$2]}` in GTK `variantName $2` theme, change to: "
		fi
		read input
	done
	if [[ $input != "" ]]
	then
		gtkNewColorMap[$1,$2]=$input
		if [[ ! " ${gtkEditedColorArray[@]} " =~ " ${1} " ]]
		then
			gtkEditedColorArray[$gtkEditedColorIndex]=$1
			(( gtkEditedColorIndex++ ))
		fi
	fi
}

gnomeToGTK () {
	if [[ ${gnomeNewColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		if [[ ${gnomeColorMap[$1,0]} == ${gtkColorMap[$1,0]} ]]
		then
			gtkNewColorMap[$1,0]=${gnomeNewColorMap[$1,0]}
			gtkEditedColorArray[$gtkEditedColorIndex]=$1
			(( gtkEditedColorIndex++ ))
		else
			gtkGetUserInput $1 "0"
		fi
	fi	
	if [[ ${gnomeNewColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		if [[ ${gnomeColorMap[$1,1]} == ${gtkColorMap[$1,1]} ]]
		then
			gtkNewColorMap[$1,1]=${gnomeNewColorMap[$1,1]}
			newIndex=true
			if [[ ! " ${gtkEditedColorArray[@]} " =~ " ${1} " ]]
			then
				gtkEditedColorArray[$gtkEditedColorIndex]=$1
				(( gtkEditedColorIndex++ ))
			fi
		else
			gtkGetUserInput $1 "1"
		fi
	fi	
	if [[ ! ${gnomeNewColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$ 
		&& ! ${gnomeColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$
		&& ${gtkColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		gtkGetUserInput $1 "0"
	fi
	if [[ ! ${gnomeNewColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$ 
		&& ! ${gnomeColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$
		&& ${gtkColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		gtkGetUserInput $1 "1"
	fi
}

echo -e "\nGTK theme shows differences from Gnome theme on the following colors:"

for color in ${newColorArray[*]}
do
	gnomeToGTK $color
done

gtkDisplayEdition () {
	echo -e 'Edited Light New Dark New Neutral New'
	declare -a validColors	
	colorsToFile="GTK \nColor Light Dark Neutral \n"
	size=${#gtkNewColorMap[@]}
	count=0
	for color in ${gtkEditedColorArray[*]} 
	do
		for i in {0..2}
		do
			if [[ ${gtkNewColorMap[$color,$i]} =~ ^#[0-9A-Fa-f]{6}$ ]]
			then 
				validColors[$i]=${gtkNewColorMap[$color,$i]}
				(( count++ ))
			else 
				validColors[$i]=$placeholder
			fi
		done
		echo -ne "Parsing color code $count of $size"\\r 1>&2
		colorsToFile+="\n$color ${validColors[0]} ${validColors[1]} ${validColors[2]}"
		echo -e `editionFormatColors "$color" "${gtkColorMap[$color,0]}" "${validColors[0]}" "${gtkColorMap[$color,1]}" "${validColors[1]}" "${gtkColorMap[$color,2]}" "${validColors[2]}"`
	done 
	echo -e $colorsToFile | column -t >> $colorsFile
}

gtkReplaceColor () {
	if [[ ${gtkNewColorMap[$1,0]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gtkColorMap[$1,0]},/${gtkNewColorMap[$1,0]},/g" $modDir$gtkPopOsColors
		sed -i "s/${gtkColorMap[$1,0]},/${gtkNewColorMap[$1,0]},/g" $modDir$gtkColors
		sed -i "s/${gtkColorMap[$1,0]},/${gtkNewColorMap[$1,0]},/g" $modDir$gtkUbuntuColors
	fi
	if [[ ${gtkNewColorMap[$1,1]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gtkColorMap[$1,1]})/${gtkNewColorMap[$1,1]})/g" $modDir$gtkPopOsColors
		sed -i "s/${gtkColorMap[$1,1]})/${gtkNewColorMap[$1,1]})/g" $modDir$gtkColors
		sed -i "s/${gtkColorMap[$1,1]})/${gtkNewColorMap[$1,1]})/g" $modDir$gtkUbuntuColors
	fi
	if [[ ${gtkNewColorMap[$1,2]} =~ ^#[0-9A-Fa-f]{6}$ ]]
	then
		sed -i "s/${gtkColorMap[$1,2]};/${gtkNewColorMap[$1,2]};/g" $modDir$gtkPopOsColors
	fi
}

echo -e "\nModified colors in GTK theme"
gtkDisplayEdition | column -t

for color in ${gtkEditedColorArray[*]}
do
	gtkReplaceColor $color
	if [[ $color == "\$orange" ]]
	then
		sed -i "s/${gtkColorMap[$color,0]}/${gtkNewColorMap[$color,0]}/g" $modDir$gtkTweaks
	fi
done

# End of GTK colors edition

# Export

sed -i "s/project('Pop'/project(\'$exportDir\'/g" "$modDir/meson.build"

[[ -d $exportDir ]] && rm -r $exportDir
cp -r $modDir $exportDir
rm -r .modified_*

# End of export

# Installation

if ! $install
then
	input="."
	while [[ ! $input =~ ^(y|Y|yes|Yes|n|N|no|No)$ && $input != "" ]]
	do
		echo -ne "\nYou're done editing $exportDir theme, do you want to install it? [Y/n]"
		read input
	done
	[[ $input =~ ^(n|N|no|No)$ ]] && exit || echo -e "\n"
else
	echo -e "\nYou're done editing $exportDir theme, it will now be installed.\n"
fi

installTheme

# End of installation

