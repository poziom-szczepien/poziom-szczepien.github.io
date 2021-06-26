#!/bin/bash

set -e
set -o nounset

buildDirectory="build"
outDirectory="resources"
dataDirectory="data"

mkdir -p $buildDirectory

echo "Building counties"

echo "Processing counties population data"
csvtojson $dataDirectory/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq '.[] | {
county: .Nazwa | sub(" *\\(\\d+\\)";"") | sub(" - miasto"; "") | sub(" - obszar wiejski"; "") | sub(" - dzielnica *(\\(\\d\\))*"; "") | sub("M.st.Warszawa"; "Warszawa") | sub(" od \\d{4}";""),
original_count_name: .Nazwa,
code: .Kod,
"12_19": (((."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 10 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s "." > $buildDirectory/counties-step-1.json

echo  "Processing counties vaccination data (property rename)"
jq '.[] | {
  county:(.gmina_nazwa | sub("gm.(m-w.)?(w.)? *"; "") | sub("M. St. "; "")),
  w1_12_19: .w1_12_19,
  w1_20_39: .w1_20_39,
  w1_40_59: .w1_40_59,
  w1_60_69: .w1_60_69,
  w1_70plus: .w1_70plus,
  w1_12_19: .w1_12_19,
  population: .liczba_ludnosci,
  atLeastOneDose: .w1_zaszczepieni_pacjenci,
  fullyVaccinated: .w3_zaszczepieni_pelna_dawka,
}' $dataDirectory/vaccine-counties.json | jq -s "."  > $buildDirectory/counties-step-2.json

echo "Connecting population data with vaccination data"
jq -s 'flatten | group_by(.county + (.population | tostring)) | map(reduce .[] as $x ({}; . * $x))'  $buildDirectory/counties-step-2.json $buildDirectory/counties-step-1.json > $buildDirectory/counties-step-3.json

echo "Connecting population and vaccination data with geo data (stage 1)"
jq --slurpfile dm $buildDirectory/counties-step-3.json '
  INDEX($dm[0][]; .code) as $dmDict
  | .features[].properties as $c |
  $c + (
      if $dmDict[$c.JPT_KOD_JE]
      then $dmDict[$c.JPT_KOD_JE]
      else {}
      end
    )
' $dataDirectory/counties.geo.json |  jq -s "."> $buildDirectory/counties-step-4.json

echo "Connecting population and vaccination data with geo data (stage 2)"
jq --slurpfile vc $buildDirectory/counties-step-4.json -c '
  INDEX($vc[0][]; .code) as $vcDict
  | walk(
    if type == "object" and .JPT_KOD_JE != null
    then . + (
      if $vcDict[.JPT_KOD_JE]
      then $vcDict[.JPT_KOD_JE]
      else {}
      end
    )
    else .
    end
  )
' $dataDirectory/counties.geo.json  > $buildDirectory/counties-step-5.json

echo "Copying result to $outDirectory"
cp $buildDirectory/counties-step-5.json $outDirectory/counties.geo.json