#!/bin/bash

set -e
set -o nounset

buildDirectory="build"
outDirectory="resources"
dataDirectory="data"

mkdir -p $buildDirectory/communities

csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq -r '.[] |  .Kod | sub("\\d$"; "")' > $buildDirectory/communities-codes.json

echo "Downloading gov data (this will take 60 min)"
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

echo "#### Building communities ####"

echo "Processing communities population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq '.[] | {
original_name: .Nazwa,
teryt: .Kod,
name: ((.Nazwa | sub(" *\\(\\d+\\)";"") | sub(" - miasto"; "") | sub(" - obszar wiejski"; "") | sub(" - dzielnica *(\\(\\d\\))*"; "") | sub("M.st.Warszawa"; "Warszawa") | sub(" od \\d{4}";""))),
"0_4": (."0-4" |  tonumber),
"5_9": (."5-9" |  tonumber),
"10_14": (."10-14" |  tonumber),
"15_19": (."15-19" |  tonumber),
"12_19": (((."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 10 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
} ' | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)'> $outDirectory/communities-population.json


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

echo "Processing districts population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210624222104.csv --delimiter=';'|  jq '.[] | {
name: .Nazwa|sub("Powiat *(m\\.)* *(st\\.)* *";""),
original_name: .Nazwa,
teryt: .Kod[:4],
"0_4": (."0-4" |  tonumber),
"5_9": (."5-9" |  tonumber),
"10_14": (."10-14" |  tonumber),
"15_19": (."15-19" |  tonumber),
"12_19": (((."0-4" | tonumber) + (."5-9" | tonumber) + (."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 19 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)' > $outDirectory/districts-population.json

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

echo "Processing voivodeships population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210703214543.csv --delimiter=';'|  jq '.[] | {
name: .Nazwa|sub("Powiat *(m\\.)* *(st\\.)* *";""),
original_name: .Nazwa,
teryt: .Kod[:2],
"0_4": (."0-4" |  tonumber),
"5_9": (."5-9" |  tonumber),
"10_14": (."10-14" |  tonumber),
"15_19": (."15-19" |  tonumber),
"12_19": (((."0-4" | tonumber) + (."5-9" | tonumber) + (."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 19 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s '. | group_by(.teryt)[] | {(.[0].teryt): .[0] }' | jq -s 'reduce .[] as $i ({}; . + $i)' > $outDirectory/voivodeships-population.json

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