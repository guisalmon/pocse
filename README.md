# POCSE (Pop OS Color Scheme Editor)
> **A note of warning:** this script isn't a fully fledged theme editor, it's merely an attempt at simplifying the edition of Pop OS color scheme, initially only for my personal use. If you choose to use it, be aware that I am in no way responsible for you breaking the visual integrity of your OS.
>
> I've been using GNU/Linux systems for long enough to know that what works in one setup might not work in another setup, sometimes for very obscure reasons.
>
> You might consider that features are missing, that stuff is rough around the edges, that I didn't give a fuck about optimization, that code is dirty, and you'd be right, I've been working on this on and off during the past two weeks and in no way do I claim that it is exhaustive nor beautifully executed.
>
> If you find some bugs, feel free to file an issue, I might or might not fix it. If you know how to shell, please don't judge me, I'm in no way a bash wizard, but feel free to open a PR with whatever regex/sed/awk based dark magic you think would improve this script. If you feel that this would require a full GUI to be usable, I feel you but I also don't want to spend time building it right now. Feel free to give it a try and reuse whatever is reusable here.

> **Thanks to the whole System76 team for the amazing work on Pop!_OS, it is the most polished and well maintained distro I've used in ages.**

## TL;DR

This script allows you to edit Pop!_OS theme using your own color scheme. 

(Pop!_OS official theme)[https://github.com/pop-os/gtk-theme]

## Requirements

### Inherited from the Pop!_OS theme: 

```
 * Gtk+-3.0             >= 3.22
 * Gtk+-2.0             >= 2.24.30
 * gtk2-engines-pixbuf  >= 2.24.30
 * gtk2-engines-murrine >= 0.98.1
```

### Dependencies:

```
* jq				 # Used to parse TermX color codes
* curl				 # Used to download resources
* git				 # Used to checkout the last Pop!_OS theme
* sassc				 # Used in Pop!_OS theme build scripts
* meson				 # Used in Pop!_OS theme build scripts
* libglib2.0-dev	 # Used in Pop!_OS theme build scripts
```

## Installation

It's a simple bash script so not much to do, really.

```
# Install dependencies
sudo apt install jq curl git sassc meson libglib2.0-dev

# Clone this project
git clone git@github.com:guisalmon/pocse.git
cd pocse

# Use it
./pop_customization.sh [OPTIONS]
```

## Usage

```
Usage: pop_customization [OPTIONS] 
Generates a Pop OS based theme with a custom color scheme.

 -d                Force download of reference theme from Pop OS git repo. 
 -i                Install theme after customization 
 -r                Reset installed theme to vanilla Pop OS theme. 
 -h                Display this help and exit. 
 -c                Use terminal colors for preview (compatible with most modern terminals) 
 -e                Edit theme after parsing of colors 
 -u [DIRECTORY]    Update a previously edited theme 
 -o NAME           Specify a name for the new theme 
 -s FILE           Use a previously exported scheme from color_exports instead of manually edit colors
```

### -i, -e, -o

These options will avoid you being prompted for a new theme name (`-o NAME`), to confirm edition (`-e`), or to confirm installation (`-i`) during the script's run.

### -c

This option is highly recommended as it will allow you to display colors in the terminal. 
*Here is an example of the kind of output it allows and how it can make color scheme edition much more comfortable*

![Colored output example 1](https://raw.githubusercontent.com/guisalmon/pocse/master/res/raw/example1.png)

Please note that the script will need to compute and parse a TermX color code for every new color you'll add during edition, which can take a while the first time. Then every new color is cached and you won't have to wait again while reusing this color. Also note that TermX colors cover only 256 colors, so what is displayed is only an approximation.

### -u, -s

`-u [DIRECTORY]` will allow you to reuse a previously edited theme as reference theme for edition rather than Pop!_OS vanilla theme. Previously edited theme are stored in directories named `Pop-[some_name_you_previously_chose]` at the root of this script's directory. This is useful if you want to edit a previous custom theme.

`-s NAME` will allow you to reuse color schemes that were generated in previous runs. Those previous color schemes are stored in `color_exports` This might be useful if you realize you want to edit additional colors on a previous theme or if System76 have updated their theme and you want to try to apply a previous color scheme to their latest theme version.

### -r

You fucked up your theme. Nothing is legible anymore, contrasts suck and you really need to revert whatever shit you've done. Fear not, and just type

```
./pop_optimization.sh -r
```

Then restart your shell and the last theme you edited should be overwritten with Pop!_OS vanilla theme. You can use `-o NAME`if you want to overwrite a specific theme. 

### -d

Delete previously downloaded Pop!_OS reference theme and re-download it.

## Examples

The following will run the script with colors enabled, parse colors from reference theme, ask you if you want to modify them, let you edit colors, ask you if you want to install the resulting theme, ask you for a theme name then install it.

```
./pop_optimization.sh -c
```

The following will run the script with colors enabled, start edition without asking you, let you edit colors and install the theme without asking you under the name `Pop-Custom` (the `Pop-` prefix is added by the script as a way to identify user themes). 

```
./pop_customization.sh -c -e -i -o Custom
```

The following will apply colors from `Pop-Custom` to your new theme, let you edit whatever colors were not edited in `Pop-Custom` and install it as `Pop-Custom2`

```
./pop_customization.sh -e -i -s color_exports/Pop-Custom_colors -o Custom2
```

The following will let you edit `Pop-Custom2`

```
./pop_optimization.sh -u Pop-Custom2
```

## Post installation

The theme should appear in `gnome-tweak-tool` for `applications` and `shell` under the name `Pop-your_name` for the light version and `Pop-your_name-dark` for the dark version.

It is advised to reload the shell after setting it by typing `alt f2` then `r`.

Sometimes this won't be enough to fully apply the themes, then restarting the system should solve the issue.

## License

### This script: 

GPL-3.0+

### Upstream Pop!_OS theme:

Most files: GPL-3.0+
Upstream Adwaita: LGPLv2.1
Sound theme: CC-BY-SA-4.0


 > **Note:**
 >
 > SVG files are licensed under CC BY-SA 4.0