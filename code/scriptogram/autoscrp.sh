
# Usage: ./autoscrp.sh [OPTION]... [FILE]
# Publish FILE to Scriptogr.am account (grabbing metadata as we go).
# FILE should have no extension.
#
# Expects tags.txt accompanying named file to pull metadata from.
# Expects there two text files in location of script,
# one containing app key for Scriptogram,
# the other containing the user ID.
#
# 	-d 		Delete file.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$1" == "-d" ]
then
	echo "Deleting..."
	URL="http://scriptogr.am/api/article/delete/"
	fileparam="-d filename=$2.md"
	filedata=""
	echo $2
else

	echo "Creating image map..."
	declare -A imagemap

	while read -r line || [[ -n $line ]]; do
		arr=(${line//,/ })
		imagemap[${arr[0]}]=${arr[1]}
	done < "$DIR"/../../userdata/picasa/imagemap.csv

	echo "Adding..."
	URL="http://scriptogr.am/api/article/post/"
	fileparam="-d name=$1"
	header=$(grep -E --max-count=1 '^\#[^#]*?$' "$DIR"/../../content/archives/$1/$1.md)
	bareheader=${header#\# }
	contents=$(grep -Ev '^\#[^#]*?$' "$DIR"/../../content/archives/$1/$1.md)
	username=$(<"$DIR"/../../userdata/scriptogram/scrpname.txt)

	fileparsed="${contents//\(\/\$\//\(\/$username\/post\/}"

	re='(.*^\!\[[[:print:]]+\]\()\/\!\/([0-9a-z\.\-]+)(\).*)'
	while [[ $fileparsed =~ $re ]]; do

		if [ ${imagemap[${BASH_REMATCH[2]}]+isset} ]; then
			echo "Image ${BASH_REMATCH[2]} found. Using existing address."
			fileparsed=${BASH_REMATCH[1]}${imagemap[${BASH_REMATCH[2]}]}${BASH_REMATCH[3]}
		else
			echo "Publishing ${BASH_REMATCH[2]}"
			if IMGRTN=$("$DIR"/../picasa/post-image.sh -f ${BASH_REMATCH[2]}); then
				echo "Image published okay."
				fileparsed=${BASH_REMATCH[1]}${IMGRTN}${BASH_REMATCH[3]}
			else
				echo "Problem with publishing an image referenced within the post." 1>&2
				exit 1
			fi
		fi

	done

	datetime=$(<"$DIR"/../../content/archives/"$1"/date.txt)
	tags=$(awk -v OFS=', ' -v RS= '{$1=$1}1' "$DIR"/../../content/archives/$1/tags.txt)
	metadata=$(echo -e "Title: $bareheader\nDate: $datetime\nTags: $tags\nSlug: $1\n")
	filedata="$metadata"$'\n\n'"$fileparsed"
	echo $1
fi

curl \
       --data-urlencode app_key@"$DIR/../../userdata/scriptogram/scrpakey.txt" \
       --data-urlencode user_id@"$DIR/../../userdata/scriptogram/scrpuser.txt" \
       "$fileparam" \
       --data-urlencode text="$filedata" \
       $URL
