# Districts

```shell
jq 'unique_by(.powiat_nazwa) | [.[].powiat_nazwa] | flatten ' original/vaccine-counties.json > districts.json
```

```shell
jq 'def reduce_sum(s): reduce s as $x (0; .+$x);
def reduce_as_is(s): reduce s as $x (0; $x);
group_by(.powiat_nazwa) | .[] | {
  district: reduce_as_is(.[] | .powiat_nazwa),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  w1_20_39: reduce_sum(.[] | .w1_20_39 | tonumber),
  w1_40_59: reduce_sum(.[] | .w1_40_59 | tonumber),
  w1_60_69: reduce_sum(.[] | .w1_60_69 | tonumber),
  w1_70plus: reduce_sum(.[] | .w1_70plus | tonumber),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  population: reduce_sum(.[] | .liczba_ludnosci | tonumber),
  atLeastOneDose: reduce_sum(.[] | .w1_zaszczepieni_pacjenci | tonumber),
  fullyVaccinated: reduce_sum(.[] | .w3_zaszczepieni_pelna_dawka | tonumber)
}' original/vaccine-counties.json | jq -s "."  > vaccine-districts_step_1.json
```

https://bdl.stat.gov.pl/BDL/dane/podgrup/temat -> LUDNOŚĆ -> STAN LUDNOŚCI -> Ludność wg grup wieku i płci -> dalej -> 2020 -> Wiek (wszystko) -> ogółem -> dalej -> Zaznacz wszystkie powiaty -> dalej -> eksportuj do csv

```shell
csvtojson original/LUDN_2137_CTAB_20210624222104.csv --delimiter=';'|  jq '.[] | {
district: .Nazwa|sub("Powiat *(m\\.)* *(st\\.)* *";""),
"12_19": (((."0-4" | tonumber) + (."5-9" | tonumber) + (."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 19 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber)
}' | jq -s 'group_by(.district)[] | reduce .[] as $i ({
"12_19": 0,
"20_39": 0,
"40_59": 0,
"60_69": 0,
"70plus":0
}; {
district: $i.district,
"12_19": (."12_19" + $i."12_19"),
"20_39": (."20_39" + $i."20_39"),
"40_59": (."40_59" + $i."40_59"),
"60_69": (."60_69" + $i."60_69"),
"70plus": (."70plus" + $i."70plus")
})' | jq -s "." > poland-demography-by-districts.json
```

```shell
jq -s 'flatten | group_by(.district) | map(reduce .[] as $x ({}; . * $x))' vaccine-districts_step_1.json poland-demography-by-districts.json > vaccine-districts_step_2.json
```

```shell
jq --slurpfile vd vaccine-districts_step_2.json ' 
  INDEX($vd[0][]; .district) as $vdDict
  | .features[].properties as $d |
  $d +$vdDict[($d.nazwa | sub("powiat ?";""))] 
' original/districts.geo.json |  jq -s "."> vaccine-districts_step_3.json
```

```shell
jq --slurpfile vd vaccine-districts_step_3.json -c ' 
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
' original/districts.geo.json > vaccine-districts_final.json
```

# Counties

```shell
jq 'def reduce_sum(s): reduce s as $x (0; .+$x);
def reduce_as_is(s): reduce s as $x (0; $x);
group_by((.gmina_nazwa | sub("gm.(m-w.)?(w.)? *"; "") | sub("M. St. "; ""))) | .[] | {
  county: reduce_as_is(.[] | (.gmina_nazwa | sub("gm.(m-w.)?(w.)? *"; "") | sub("M. St. "; ""))),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  w1_20_39: reduce_sum(.[] | .w1_20_39 | tonumber),
  w1_40_59: reduce_sum(.[] | .w1_40_59 | tonumber),
  w1_60_69: reduce_sum(.[] | .w1_60_69 | tonumber),
  w1_70plus: reduce_sum(.[] | .w1_70plus | tonumber),
  w1_12_19: reduce_sum(.[] | .w1_12_19 | tonumber),
  population: reduce_sum(.[] | .liczba_ludnosci | tonumber),
  atLeastOneDose: reduce_sum(.[] | .w1_zaszczepieni_pacjenci | tonumber),
  fullyVaccinated: reduce_sum(.[] | .w3_zaszczepieni_pelna_dawka | tonumber)
}' original/vaccine-counties.json | jq -s "."  > vaccine-counties-step-1.json
```

https://bdl.stat.gov.pl/BDL/dane/podgrup/temat -> LUDNOŚĆ -> STAN LUDNOŚCI -> Ludność wg grup wieku i płci -> dalej -> 2020 -> Wiek (wszystko) -> ogółem -> dalej -> Zaznacz wszystkie gminy -> dalej -> eksportuj do csv

```shell
csvtojson original/LUDN_2137_CTAB_20210625164329.csv --delimiter=';'|  jq '.[] | {
county: .Nazwa | sub(" *\\(\\d+\\)";"") ,
code: .Kod,
"12_19": (((."0-4" | tonumber) + (."5-9" | tonumber) + (."10-14" | tonumber) + (."15-19" | tonumber)) * 8 / 19 ) | floor,
"20_39": ((."20-24" |  tonumber) + (."25-29" | tonumber) + (."30-34" | tonumber) + (."35-39" | tonumber) ),
"40_59": ((."40-44" |  tonumber) + (."45-49" | tonumber) + (."50-54" | tonumber) + (."55-59" | tonumber) ),
"60_69": ((."60-64" |  tonumber) + (."65-69" | tonumber)),
"70plus": (."70 i więcej" | tonumber),
"population": (."ogółem" | tonumber)
}' | jq -s 'group_by(.county)[] | reduce .[] as $i ({
"12_19": 0,
"20_39": 0,
"40_59": 0,
"60_69": 0,
"70plus":0,
"population": 0
}; {
county: $i.county,
"12_19": (."12_19" + $i."12_19"),
"20_39": (."20_39" + $i."20_39"),
"40_59": (."40_59" + $i."40_59"),
"60_69": (."60_69" + $i."60_69"),
"70plus": (."70plus" + $i."70plus"),
"population": (."population" + $i."population")
})' | jq -s "." > poland-demography-by-counties.json
```

```shell
jq -s 'flatten | group_by((.county)) | map(reduce .[] as $x ({}; . * $x))' vaccine-counties-step-1.json poland-demography-by-counties.json > vaccine-counties-step-2.json
```

```shell
jq --slurpfile vc vaccine-counties-step-2.json ' 
  INDEX($vc[0][]; .county) as $vcDict
  | .features[].properties as $c |
  $c + (
      if $vcDict[$c.JPT_NAZWA_]
      then $vcDict[$c.JPT_NAZWA_]
      else {}
      end
    ) 
' original/counties.geo.json |  jq -s "."> vaccine-counties-step-3.json
```

```shell
jq --slurpfile vc vaccine-counties-step-3.json -c ' 
  INDEX($vc[0][]; .IIP_IDENTY) as $vcDict
  | walk(
    if type == "object" and .IIP_IDENTY != null
    then . + (
      if $vcDict[.IIP_IDENTY]
      then $vcDict[.IIP_IDENTY]
      else {}
      end
    ) 
    else .
    end
  )
' original/counties.geo.json > vaccine-counties-final.json
```