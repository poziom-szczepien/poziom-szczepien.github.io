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

    function calculateFillColor(geoUnit, vaccination, level, colorScale) {
        const vacInUnit = vaccination[geoUnit.properties.ref];
        if (!vacInUnit) {
            return;
        }

        var percentage;
        switch (level) {
            case 'fully':
                percentage = vacInUnit.fullyVaccinated / geoUnit.properties.population * 100;
                break;
            case 'atLeastOne':
                percentage = vacInUnit.atLeastOneDose / geoUnit.properties.population * 100;
                break;
            case '12_19':
                percentage = vacInUnit.w1_12_19 / geoUnit.properties["12_19"] * 100;
                break;
            case '20_39':
                percentage = vacInUnit.w1_20_39 / geoUnit.properties["20_39"] * 100;
                break;
            case '40_59':
                percentage = vacInUnit.w1_40_59 / geoUnit.properties["40_59"] * 100;
                break;
            case '60_69':
                percentage = vacInUnit.w1_60_69 / geoUnit.properties["60_69"] * 100;
                break;
            case '70plus':
                percentage = vacInUnit.w1_70plus / geoUnit.properties["70plus"] * 100;
                break;
            default:
                percentage = 0;
        }
        return colorScale(percentage);
    }

    function displayTooltip(event, geoUnit, vaccination) {
        const vacInUnit = vaccination[geoUnit.properties.ref];

        if (!vacInUnit) {
            console.log(geoUnit.properties)
            return;
        }

        d3.select('#tooltipDiv')
            .transition()
            .duration(200)
            .style("opacity", .9);
        d3.select('#tooltipDiv').html(`
                <p><strong>${vacInUnit ? vacInUnit.name : geoUnit.properties.ref}</strong></p>
                <p>Zaszczepieni: ${(vacInUnit.fullyVaccinated * 100.0 / geoUnit.properties.population).toFixed(1)}% (${vacInUnit.fullyVaccinated}/${geoUnit.properties.population})</p>
                <p>Co najmniej jedną: ${(vacInUnit.atLeastOneDose * 100.0 / geoUnit.properties.population).toFixed(1)}% (${vacInUnit.atLeastOneDose}/${geoUnit.properties.population})</p>
                <p>12-19: ~${(vacInUnit.w1_12_19 * 100.0 / geoUnit.properties["12_19"]).toFixed(1)}% (${vacInUnit.w1_12_19}/~${geoUnit.properties["12_19"]})</p>
                <p>20-39: ${(vacInUnit.w1_20_39 * 100.0 / geoUnit.properties["20_39"]).toFixed(1)}% (${vacInUnit.w1_20_39}/${geoUnit.properties["20_39"]})</p>
                <p>40-59: ${(vacInUnit.w1_40_59 * 100.0 / geoUnit.properties["40_59"]).toFixed(1)}% (${vacInUnit.w1_40_59}/${geoUnit.properties["40_59"]})</p>
                <p>60-69: ${(vacInUnit.w1_60_69 * 100.0 / geoUnit.properties["60_69"]).toFixed(1)}% (${vacInUnit.w1_60_69}/${geoUnit.properties["60_69"]})</p>
                <p>70plus: ${(vacInUnit.w1_70plus * 100.0 / geoUnit.properties["70plus"]).toFixed(1)}% (${vacInUnit.w1_70plus}/${geoUnit.properties["70plus"]})</p>
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

    function render(counties, countiesVaccination, districts, districtsVaccination, colorScale) {
        const admDivision = d3.select('#admDivisionSelect').node().value;
        const level = d3.select('#levelSelect').node().value;

        const promises = admDivision === 'community'
            ? [counties, countiesVaccination]
            : [districts, districtsVaccination];

        Promise.all(promises).then(function (arr) {
            const geoJson = arr[0];
            const vaccinationData = arr[1];

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
                .style("fill", geoUnit => calculateFillColor(geoUnit, vaccinationData, level, colorScale))
                .on("mouseover", (event, geoUnit) => displayTooltip(event, geoUnit, vaccinationData))
                .on("mouseout", () => hideTooltip());
        });
    }

    function init() {
        const colorScale = createColorScale();
        renderColorScale(colorScale);

        d3.select("svg")
            .attr("width", '1200')
            .attr("height", '800')
            .attr('viewBox', '0 0 1200 800')
            .attr('preserveAspectRatio', 'xMinYMin');

        const counties = d3.json("resources/communities-with-population.geo.json")
            .then(json => {
                json.features.forEach(function (feature) {
                    feature.geometry = turf.rewind(feature.geometry, {reverse: true});
                })
                return json;
            });
        const countiesVaccination = d3.json("resources/communities-vaccination.geo.json");
        const districts = d3.json("resources/districts-with-population.geo.json")
            .then(json => {
                json.features.forEach(function (feature) {
                    feature.geometry = turf.rewind(feature.geometry, {reverse: true});
                })
                return json;
            });
        const districtsVaccination = d3.json("resources/districts-vaccination.geo.json");

        d3.select('svg')
            .on('resize', () => render(counties, countiesVaccination, districts, districtsVaccination, colorScale));

        d3.select('#admDivisionSelect')
            .on('change', () => render(counties, countiesVaccination, districts, districtsVaccination, colorScale));

        d3.select('#levelSelect')
            .on('change', () => render(counties, countiesVaccination, districts, districtsVaccination, colorScale));

        render(counties, countiesVaccination, districts, districtsVaccination, colorScale);
    }

    init();

})();