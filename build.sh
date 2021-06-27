#!/bin/bash

set -e
set -o nounset

buildDirectory="build"
outDirectory="resources"
dataDirectory="data"

mkdir -p $buildDirectory

echo "#### Building communities ####"

echo "Processing communities population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq '.[] | {
original_name: .Nazwa,
code: .Kod,
ref: ((.Nazwa | sub(" *\\(\\d+\\)";"") | sub(" - miasto"; "") | sub(" - obszar wiejski"; "") | sub(" - dzielnica *(\\(\\d\\))*"; "") | sub("M.st.Warszawa"; "Warszawa") | sub(" od \\d{4}";"")) +  (."ogółem")),
"12_19": (((."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 10 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s "." > $buildDirectory/communities-step-1.json

echo "Connecting population with geo data (stage 1)"
jq --slurpfile dm $buildDirectory/communities-step-1.json '
  INDEX($dm[0][]; .code) as $dmDict
  | .features[].properties as $c |
  $c + (
      if $dmDict[$c.JPT_KOD_JE]
      then $dmDict[$c.JPT_KOD_JE]
      else {}
      end
    )
' $dataDirectory/communities.geo.json |  jq -s "."> $buildDirectory/communities-step-2.json

echo "Removing unnecessary fields"
jq '.[]
  | del(.JPT_SJR_KO)
  | del(.JPT_NAZWA_)
  | del(.JPT_ORGAN_)
  | del(.JPT_JOR_ID)
  | del(.WERSJA_OD)
  | del(.WERSJA_DO)
  | del(.WAZNY_OD)
  | del(.WAZNY_DO)
  | del(.JPT_KOD__1)
  | del(.JPT_NAZWA1)
  | del(.JPT_ORGAN1)
  | del(.JPT_WAZNA_)
  | del(.ID_BUFORA_)
  | del(.ID_BUFORA1)
  | del(.ID_TECHNIC)
  | del(.IIP_PRZEST)
  | del(.IIP_IDENTY)
  | del(.IIP_WERSJA)
  | del(.JPT_KJ_IIP)
  | del(.JPT_KJ_I_1)
  | del(.JPT_KJ_I_2)
  | del(.JPT_OPIS)
  | del(.JPT_SPS_KO)
  | del(.ID_BUFOR_1)
  | del(.ID_BUFOR_1)
  | del(.JPT_KJ_I_3)
  | del(.JPT_ID)
  | del(.Shape_Leng)
  | del(.Shape_Area)
' $buildDirectory/communities-step-2.json  |  jq -s "."> $buildDirectory/communities-step-3.json

echo "Connecting population and geo data (stage 2)"
jq --slurpfile vc $buildDirectory/communities-step-3.json -c '
  INDEX($vc[0][]; .code) as $vcDict
  | walk(
    if type == "object" and .JPT_KOD_JE != null
    then (
      if $vcDict[.JPT_KOD_JE]
      then $vcDict[.JPT_KOD_JE]
      else {}
      end
    )
    else .
    end
  )
' $dataDirectory/communities.geo.json  > $buildDirectory/communities-step-4.json

csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq -r '.[] |  .Kod | sub("\\d$"; "")' > $buildDirectory/communities-codes.json

mkdir -p $buildDirectory/communities

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

echo  "Processing communities vaccination data (property rename)"
jq '. | {
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
}' build/communities/* | jq -s '.' > $buildDirectory/communities-step-5.json

jq -s '.[] | group_by(.name  + (.population | tostring))[] | {(.[0].name + (.[0].population | tostring)): .[0]}' $buildDirectory/communities-step-5.json | jq -s '. | reduce .[] as $i ({}; . + $i)'  > $buildDirectory/communities-step-6.json

echo "Copying result to $outDirectory"
cp $buildDirectory/communities-step-4.json $outDirectory/communities-with-population.geo.json
cp $buildDirectory/communities-step-6.json $outDirectory/communities-vaccination.geo.json


echo "#### Building districts ####"

echo "Processing districts population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210624222104.csv --delimiter=';'|  jq '.[] | {
district: .Nazwa|sub("Powiat *(m\\.)* *(st\\.)* *";""),
original_name: .Nazwa,
code: .Kod,
"12_19": (((."0-4" | tonumber) + (."5-9" | tonumber) + (."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 19 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s 'group_by(.district)[] | reduce .[] as $i ({
"12_19": 0,
"20_39": 0,
"40_59": 0,
"60_69": 0,
"70plus":0,
"population": 0
}; {
district: $i.district,
name: $i.district,
ref: $i.district,
original_name: $i.original_name,
code: $i.code,
"12_19": (."12_19" + $i."12_19"),
"20_39": (."20_39" + $i."20_39"),
"40_59": (."40_59" + $i."40_59"),
"60_69": (."60_69" + $i."60_69"),
"70plus": (."70plus" + $i."70plus"),
"population": (."population" + $i."population")
})' | jq -s "." > $buildDirectory/districts-step-1.json

echo "Connecting population and geo data (stage 1)"
jq --slurpfile vd $buildDirectory/districts-step-1.json '
  INDEX($vd[0][]; .district) as $vdDict
  | .features[].properties as $d |
  $d +$vdDict[($d.nazwa | sub("powiat ?";""))]
' $dataDirectory/districts.geo.json |  jq -s "."> $buildDirectory/districts-step-2.json

echo "Connecting population and geo data (stage 2)"
jq --slurpfile vd $buildDirectory/districts-step-2.json -c '
  INDEX($vd[0][]; .nazwa) as $vdDict
  | walk(
    if type == "object" and .nazwa != null
    then . + (
      if $vdDict[.nazwa]
      then $vdDict[.nazwa]
      else {}
      end
    )
    else .
    end
  )
' $dataDirectory/districts.geo.json > $buildDirectory/districts-step-3.json

echo "Processing vaccination counties data to vaccination districts data"
jq 'def reduce_sum(s): reduce s as $x (0; .+$x);
def reduce_as_is(s): reduce s as $x (0; $x);
group_by(.powiat_nazwa) | .[] | {
  name: reduce_as_is(.[] | .powiat_nazwa),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  w1_20_39: reduce_sum(.[] | .w1_20_39 | tonumber),
  w1_40_59: reduce_sum(.[] | .w1_40_59 | tonumber),
  w1_60_69: reduce_sum(.[] | .w1_60_69 | tonumber),
  w1_70plus: reduce_sum(.[] | .w1_70plus | tonumber),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  population: reduce_sum(.[] | .liczba_ludnosci | tonumber),
  atLeastOneDose: reduce_sum(.[] | .w1_zaszczepieni_pacjenci | tonumber),
  fullyVaccinated: reduce_sum(.[] | .w3_zaszczepieni_pelna_dawka | tonumber)
}' $dataDirectory/vaccine-counties.json | jq -s "."  > $buildDirectory/districts-step-4.json

jq -s '.[] | group_by(.name)[] | {(.[0].name): .[0]}' $buildDirectory/districts-step-4.json | jq -s '. | reduce .[] as $i ({}; . + $i)'  > $buildDirectory/districts-step-5.json

echo "Copying result to $outDirectory"
cp $buildDirectory/districts-step-3.json $outDirectory/districts-with-population.geo.json
cp $buildDirectory/districts-step-5.json $outDirectory/districts-vaccination.geo.json

#rm -r $buildDirectory