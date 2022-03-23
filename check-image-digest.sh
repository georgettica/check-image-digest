#!/bin/bash

set -eEuo pipefail

for bin in skopeo jq; do
	if [[ ! $(which ${bin}) ]]; then
		echo "required binary ${bin} does not exist on machine, exiting"
		exit 1
	fi
done

if [[ -z "${DIGEST}" ]]; then
    echo "Must provide DIGEST in environment" 1>&2
    exit 1
fi
want_digest=${DIGEST}

ERR_NO_MATCH=2

IMAGE_PREFIX=${IMAGE_PREFIX:-'latest'}
echo "Using image prefix '${IMAGE_PREFIX}' (modify IMAGE_PREFIX) to change"
IMAGE_NAME=${IMAGE_NAME:-'ubuntu'}
echo "Using image name '${IMAGE_NAME}' (modify IMAGE_NAME) to change"

parsed_images=$(skopeo list-tags docker://"${IMAGE_NAME}" | jq --raw-output --arg image_prefix "${IMAGE_PREFIX}" '"docker://\(.Repository):\(.Tags[] | select(startswith($image_prefix)))"')

matching_images=()
for parsed_image in ${parsed_images}; do 
	echo "Verifiying '$parsed_image' matches digest provided:"
	got_digest=$(skopeo inspect "${parsed_image}" --no-tags --format '{{.Digest}}')
	if [[ "${got_digest}" == "${want_digest}" ]]; then
		matching_images+=( "${parsed_images}" )
		continue
	fi
done

if [[ "${#matching_images[@]}" -eq 0 ]]; then
	echo ' Did not find matches, change any of the flags and try again'
	exit "${ERR_NO_MATCH}"
fi

echo "Found '${#matching_images[@]}' matches"
for matching_image in "${matching_images[@]}"; do
	echo "a matching image is '${matching_image}'"
done

