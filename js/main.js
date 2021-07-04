(function () {
    function createColorScale() {
        return chroma.scale(['white', 'darkblue'])
            .domain([0, 100])
            .gamma(1);
    }

    function renderColorScale(colorScale) {
        for (i = 0; i < 100; i++) {
            d3.select(".gradient")
                .append("span")
                .attr('class', "grad-step")
                .style("background-color", colorScale(i));
        }
    }

    function calculateFillColor(geoUnit, vaccination, population, level, colorScale) {
        const teryt = geoUnit.properties.teryt;
        if (!teryt) {
            return;
        }
        const vaccinationInUnit = vaccination[teryt] || vaccination[teryt.substring(0, Math.min(teryt.length, 6))];
        const populationInUnit = population[teryt] || population[teryt.substring(0, Math.min(teryt.length, 6))];

        if (!vaccinationInUnit || !populationInUnit) {
            return;
        }

        var percentage;
        switch (level) {
            case 'fully':
                percentage = vaccinationInUnit.fullyVaccinated / populationInUnit.population * 100;
                break;
            case 'atLeastOne':
                percentage = vaccinationInUnit.atLeastOneDose / populationInUnit.population * 100;
                break;
            case '12_19':
                percentage = vaccinationInUnit.w1_12_19 / populationInUnit["12_19"] * 100;
                break;
            case '20_39':
                percentage = vaccinationInUnit.w1_20_39 / populationInUnit["20_39"] * 100;
                break;
            case '40_59':
                percentage = vaccinationInUnit.w1_40_59 / populationInUnit["40_59"] * 100;
                break;
            case '60_69':
                percentage = vaccinationInUnit.w1_60_69 / populationInUnit["60_69"] * 100;
                break;
            case '70plus':
                percentage = vaccinationInUnit.w1_70plus / populationInUnit["70plus"] * 100;
                break;
            default:
                percentage = 0;
        }
        return colorScale(percentage);
    }

    function displayTooltip(event, geoUnit, vaccination, population, level) {
        const teryt = geoUnit.properties.teryt;
        if (!teryt) {
            return;
        }
        const vaccinationInUnit = vaccination[teryt] || vaccination[teryt.substring(0, 6)];
        const populationInUnit = population[teryt] || population[teryt.substring(0, 6)];

        if (!vaccinationInUnit || !populationInUnit) {
            return;
        }

        d3.select('#tooltipDiv')
            .transition()
            .duration(200)
            .style("opacity", .9);
        d3.select('#tooltipDiv').html(`
                <p><strong>${geoUnit.properties.name}</strong></p>
                <p >Zaszczepieni: <span ${level === 'fully' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.fullyVaccinated * 100.0 / populationInUnit.population).toFixed(1)}%</span> (${vaccinationInUnit.fullyVaccinated}/${populationInUnit.population})</p>
                <p>Co najmniej jedną: <span ${level === 'atLeastOne' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.atLeastOneDose * 100.0 / populationInUnit.population).toFixed(1)}%</span> (${vaccinationInUnit.atLeastOneDose}/${populationInUnit.population})</p>
                <p>12-19: <span ${level === '12_19' ? 'class="fw-bold"' : ''}>~${(vaccinationInUnit.w1_12_19 * 100.0 / populationInUnit["12_19"]).toFixed(1)}%</span> (${vaccinationInUnit.w1_12_19}/~${populationInUnit["12_19"]})</p>
                <p>20-39: <span ${level === '20_39' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.w1_20_39 * 100.0 / populationInUnit["20_39"]).toFixed(1)}%</span> (${vaccinationInUnit.w1_20_39}/${populationInUnit["20_39"]})</p>
                <p>40-59: <span ${level === '40_59' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.w1_40_59 * 100.0 / populationInUnit["40_59"]).toFixed(1)}%</span> (${vaccinationInUnit.w1_40_59}/${populationInUnit["40_59"]})</p>
                <p>60-69: <span ${level === '60_69' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.w1_60_69 * 100.0 / populationInUnit["60_69"]).toFixed(1)}%</span> (${vaccinationInUnit.w1_60_69}/${populationInUnit["60_69"]})</p>
                <p>70plus: <span ${level === '70plus' ? 'class="fw-bold"' : ''}>${(vaccinationInUnit.w1_70plus * 100.0 / populationInUnit["70plus"]).toFixed(1)}%</span> (${vaccinationInUnit.w1_70plus}/${populationInUnit["70plus"]})</p>
                <small>Dla wszystkich grup wiekowych wartość<br>dotyczy zaszczepionych co najmniej jedną dawką</small>
                `)
            .style("left", (event.pageX) + "px")
            .style("top", (event.pageY) + "px");
    }

    function hideTooltip() {
        d3.select('#tooltipDiv').transition()
            .duration(500)
            .style("opacity", 0);
    }

    function render(dataProvider, colorScale) {
        const admDivision = d3.select('#admDivisionSelect').node().value;
        const level = d3.select('#levelSelect').node().value;

        const promises = admDivision === 'community'
            ? [dataProvider.getCommunities(), dataProvider.getCommunitiesVaccination(), dataProvider.getCommunitiesPopulation()]
            : admDivision === 'district'
                ? [dataProvider.getDistricts(), dataProvider.getDistrictsVaccination(), dataProvider.getDistrictsPopulation()]
                : [dataProvider.getVoivodeships(), dataProvider.getVoivodeshipsVaccination(), dataProvider.getVoivodeshipsPopulation()]

        Promise.all(promises).then(function (arr) {
            const geoJson = arr[0];
            const vaccination = arr[1];
            const population = arr[2];

            const svg = d3.select("svg");

            const projection = d3.geoMercator()
                .fitSize([svg.attr("width"), svg.attr("height")], geoJson);

            const path = d3.geoPath()
                .projection(projection);

            svg.selectAll("path")
                .remove();

            svg.selectAll("path")
                .data(geoJson.features)
                .enter()
                .append("path")
                .attr("d", path)
                .style("fill", geoUnit => calculateFillColor(geoUnit, vaccination, population, level, colorScale))
                .on("mouseover", (event, geoUnit) => displayTooltip(event, geoUnit, vaccination, population, level))
                .on("mouseout", () => hideTooltip());
        });
    }

    function initializeDataProvider() {
        return {
            getCommunities() {
                if (!this.communities) {
                    this.communities = d3.json("resources/poland-json/geo/communities/communities-xs.geo.json")
                        .then(json => {
                            json.features.forEach(function (feature) {
                                feature.geometry = turf.rewind(feature.geometry, { reverse: true });
                            })
                            return json;
                        });
                }
                return this.communities;
            },

            getCommunitiesVaccination() {
                if (!this.cmmunitiesVaccination) {
                    this.cmmunitiesVaccination = d3.json("resources/communities-vaccination.json");
                }
                return this.cmmunitiesVaccination;
            },


            getCommunitiesPopulation() {
                if (!this.communitiesPopulation) {
                    this.communitiesPopulation = d3.json("resources/communities-population.json");
                }
                return this.communitiesPopulation;
            },

            getDistricts() {
                if (!this.districts) {
                    this.districts = d3.json("resources/poland-json/geo/districts/districts-xs.geo.json")
                        .then(json => {
                            json.features.forEach(function (feature) {
                                feature.geometry = turf.rewind(feature.geometry, { reverse: true });
                            })
                            return json;
                        });
                }
                return this.districts;
            },

            getDistrictsVaccination() {
                if (!this.districtsVaccination) {
                    this.districtsVaccination = d3.json("resources/districts-vaccination.json");
                }
                return this.districtsVaccination;
            },


            getDistrictsPopulation() {
                if (!this.districtsPopulation) {
                    this.districtsPopulation = d3.json("resources/districts-population.json");
                }
                return this.districtsPopulation;
            },

            getVoivodeships() {
                if (!this.voivodeships) {
                    this.voivodeships = d3.json("resources/poland-json/geo/voivodeships/voivodeships-xs.geo.json")
                        .then(json => {
                            json.features.forEach(function (feature) {
                                feature.geometry = turf.rewind(feature.geometry, { reverse: true });
                            })
                            return json;
                        });
                }
                return this.voivodeships;
            },

            getVoivodeshipsVaccination() {
                if (!this.voivodeshipsVaccination) {
                    this.voivodeshipsVaccination = d3.json("resources/voivodeships-vaccination.json");
                }
                return this.voivodeshipsVaccination;
            },


            getVoivodeshipsPopulation() {
                if (!this.voivodeshipsPopulation) {
                    this.voivodeshipsPopulation = d3.json("resources/voivodeships-population.json");
                }
                return this.voivodeshipsPopulation;
            }
        };
    }

    function init() {
        const colorScale = createColorScale();
        renderColorScale(colorScale);

        d3.select("svg")
            .attr("width", '1200')
            .attr("height", '800')
            .attr('viewBox', '0 0 1200 800')
            .attr('preserveAspectRatio', 'xMinYMin');

        const dataProvider = initializeDataProvider();

        d3.select('svg')
            .on('resize', () => render(dataProvider, colorScale));

        d3.select('#admDivisionSelect')
            .on('change', () => render(dataProvider, colorScale));

        d3.select('#levelSelect')
            .on('change', () => render(dataProvider, colorScale));

        render(dataProvider, colorScale);
    }

    init();

})();