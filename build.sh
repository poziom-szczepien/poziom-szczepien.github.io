#!/bin/bash

set -e
set -o nounset

buildDate=`date +%Y%m%d_%k%M%S`
buildDirectory="build"
dataDirectory="data"
outDirectory="resources/${buildDate}"

function downloadGovData() {
  while IFS="" read -r p || [ -n "$p" ]
  do
    if [ ! -f "$buildDirectory/communities/$p.json" ]; then
      sleepTime=$(shuf -i50-150 -n1)
      sleepTime=$(echo "$sleepTime/100" | bc -l)
      sleep $sleepTime

      wget -q --retry-on-http-error=429 --tries=10 --waitretry=1 -O $buildDirectory/communities/$p.json "https://www.gov.pl/api/data/covid-vaccination-contest/result-by-community/$p"
      echo -n "#"
    else
      echo -n "-"
    fi
  done < $buildDirectory/communities-codes.json

  grep -lrIZ " html>" $buildDirectory/communities | xargs -0 rm -f --
  echo ""
}

mkdir -p $buildDirectory/communities
mkdir -p $outDirectory

csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq -r '.[] |  .Kod | sub("\\d$"; "")' > $buildDirectory/communities-codes.json

echo "Downloading gov data (this will take ~60 min)"
date

downloadGovData
fileCount=$(find $buildDirectory/communities | wc -l)

while [ $fileCount -le 2470 ]; do
  echo "Retrying download..."
  sleep 10
  downloadGovData

  fileCount=$(find $buildDirectory/communities | wc -l)
done

echo "Downloaded data"
date

echo "#### Building communities ####"

echo  "Processing communities vaccination data"
jq '. | {
    "teryt": input_filename | split("/") | last | .[:6],
    "w3": .full_vaccinated_percent,
    "w1_12_19": .vaccinated_age_group12_19,
    "w1_20_39": .vaccinated_age_group20_39,
    "w1_40_59": .vaccinated_age_group40_59,
    "w1_60_69": .vaccinated_age_group60_69,
    "w1_70plus": .vaccinated_age_group70,
    "name": (.community | sub("gm.(m-w.)?(w.)? *"; "") | sub("M. St. "; "")),
    "population": .population,
    "atLeastOneDose": .half_vaccinated_amount,
    "fullyVaccinated": .full_vaccinated_amount
} ' build/communities/* | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)' > $outDirectory/communities-vaccination.json

echo "#### Building districts ####"

echo "Processing districts vaccination data"
jq '. | to_entries | map(.value) | group_by(.teryt[:4])[] | reduce .[] as $i ({
"w3": 0,
"w1_12_19": 0,
"w1_20_39": 0,
"w1_40_59": 0,
"w1_60_69": 0,
"w1_70plus": 0,
"population": 0,
"atLeastOneDose": 0,
"fullyVaccinated": 0,
}; {
"teryt": $i.teryt[:4],
"w1_12_19": (."w1_12_19" + $i."w1_12_19"),
"w1_20_39": (."w1_20_39" + $i."w1_20_39"),
"w1_40_59": (."w1_40_59" + $i."w1_40_59"),
"w1_60_69": (."w1_60_69" + $i."w1_60_69"),
"w1_70plus": (."w1_70plus" + $i."w1_70plus"),
"population": (."population" + $i."population"),
"atLeastOneDose": (."atLeastOneDose" + $i."atLeastOneDose"),
"fullyVaccinated": (."fullyVaccinated" + $i."fullyVaccinated")
})' $outDirectory/communities-vaccination.json | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)' > $outDirectory/districts-vaccination.json

echo "#### Building voivodeships ####"

echo "Processing voivodeships vaccination data"
jq '. | to_entries | map(.value) | group_by(.teryt[:2])[] | reduce .[] as $i ({
"w3": 0,
"w1_12_19": 0,
"w1_20_39": 0,
"w1_40_59": 0,
"w1_60_69": 0,
"w1_70plus": 0,
"population": 0,
"atLeastOneDose": 0,
"fullyVaccinated": 0,
}; {
"teryt": $i.teryt[:2],
"w1_12_19": (."w1_12_19" + $i."w1_12_19"),
"w1_20_39": (."w1_20_39" + $i."w1_20_39"),
"w1_40_59": (."w1_40_59" + $i."w1_40_59"),
"w1_60_69": (."w1_60_69" + $i."w1_60_69"),
"w1_70plus": (."w1_70plus" + $i."w1_70plus"),
"population": (."population" + $i."population"),
"atLeastOneDose": (."atLeastOneDose" + $i."atLeastOneDose"),
"fullyVaccinated": (."fullyVaccinated" + $i."fullyVaccinated")
})' $outDirectory/communities-vaccination.json | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)' > $outDirectory/voivodeships-vaccination.json

rm -r $buildDirectory

export BUILD_DATE="${buildDate}"
envsubst < "index.html.template" > "index.html"