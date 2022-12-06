#!/bin/bash

# this script provides some tool needed to translate the homepage.
# For dependencies, it needs python3 and python3-massedit, which you can install with `pip install massedit`.

# before you can use this script the first time, you have to initialize Transifex in this folder:
# $ tx init --user=api --pass=<your api token>
# you may also need `txt2po`, get it by `sudo apt install translate-toolkit`

# after that, call `./t-dance create-po-sources` to rebuild all non-english markdown files
# from the translations provided by transifex users

# call `./t-dance push` pushes the english markdown files to transifex

# the hidden `.tx` folder was generated by the following command:
# $ tx set --auto-remote https://www.transifex.com/projects/p/delta-chat-pages/

# common information about the Transifex CLI client can be found at:
# https://docs.transifex.com/client/

set -e

sfiles=(blog contribute community-standards download help imprint index references user-voices verify-downloads)
tlangs=(ca cs de es fr gl id it nl pl pt ru sk sq tr uk zh_CN)  # do not add `en` to this list


pull_po_translations_from_tx() {
	#find ../_data/lang/ -type f -not -name 'en.*' -delete
	rm -r translations || true
	mkdir translations 
	tx pull -a --mode=sourceastranslation  # -a = fetch all translationss, -s = fetches source
	for tlang in ${tlangs[@]}; do
	  echo "Converting ${tlang} ..."
	  for sfile in ${sfiles[@]}; do
			pofile="../${tlang}/${sfile}.po"
			cp "translations/delta-chat-pages.${sfile}po/${tlang}.po" $pofile
		done
		cp "translations/delta-chat-pages.yml/${tlang}.yml" "../_data/lang/${tlang}.yml"
	done
}


push_po_sources_to_tx() {
	branch=$(git rev-parse --abbrev-ref HEAD)
	echo $branch
	git status
	if [ -z $branch ] || [ $branch != "master" ]; then
		echo "ERROR: push is only allowed on master, there is a high risk to delete existing translations otherwise"
		exit 1
	fi
	tx push -s
}


create_po_sources() {
	for sfile in ${sfiles[@]}; do
		mkdir -p "translations/delta-chat-pages.${sfile}po"
		txt2po --progress=none "../en/${sfile}.md" "translations/delta-chat-pages.${sfile}po/en.po"
	done
	# sic: for whatever reason, the file is en.yaml and not .yml as everywhere else
	mkdir translations/delta-chat-pages.yml || true
	cp "../_data/lang/en.yaml" "translations/delta-chat-pages.yml/en.yml"
}


create_markdown_files() {
	echo "Creating markdown files from the translated po-files ..."
	for sfile in ${sfiles[@]}; do
		for tlang in ${tlangs[@]}; do
			pofile="../${tlang}/${sfile}.po"
			mdfile="../${tlang}/${sfile}.md"
			po2txt --progress=none --template="../en/${sfile}.md" $pofile $mdfile
			python3 -m massedit -e "re.sub(r'lang: [a-z][a-z](_[A-Z][A-Z])?', 'lang: ${tlang}', line)" -w $mdfile
			#sed -i "" "s/lang: [a-z][a-z]/lang: ${tlang:0:2}/" $mdfile # correct used layout - for some reasons, [a-z]{2,} does not work on sed-mac
		done
	done	
}


create_html_files() {
	# if you want to rebuild the html files when markdown is updated,
	# create the file `tools/create-html.prv.sh` with eg. the following content:
	# `cd ..; jekyll build --destination <html-folder>; echo "Options +MultiViews" > <html-folder>/.htaccess; cd tools`  
	if [ -f ./create-html.prv.sh ]; then
		echo "Creating html-files from the markdown files ..."
		./create-html.prv.sh
	fi
}


reset_markdown_files() {
	for tlang in ${tlangs[@]}; do
		git checkout "../${tlang}/"
	done
}


# convenience: allow calling as ./tools/t-dance.sh from the root dir
cd_back="false"
if [ -d "tools" ]; then
	cd tools
	cd_back="true"
fi


# normal usage
if [ $1 == "pull" ]; then
	pull_po_translations_from_tx
	create_markdown_files
	create_html_files
	cd ..
	./tools/check-translations.sh
	cd tools
elif [ $1 == "push--do-this-only-from-master" ]; then
	create_po_sources
	push_po_sources_to_tx
# debug usage
elif [ $1 == "create-po-sources" ]; then
	create_po_sources
elif [ $1 == "create-md" ]; then
	create_markdown_files	
	create_html_files
elif [ $1 == "reset-md" ]; then
	reset_markdown_files
	create_html_files
else
	echo "pull translations: ./t-dance pull"
	echo "push sources:      ./t-dance push--do-this-only-from-master"
	echo "debug usage:       ./t-dance {create-po-sources|create-md|reset-md}"
	echo "to push a single language, copy the files to translations/delta-chat-pages.<file>po/<lang>.po and call: tx push -t -l <lang>"
fi


if [ $cd_back == "true" ]; then
	cd ..
fi
