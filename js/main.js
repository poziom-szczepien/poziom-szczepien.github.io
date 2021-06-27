var colorScale = chroma.scale(['white', 'darkblue'])
    .domain([0, 100])
    .gamma(1);

for (i = 0; i < 100; i++) {
    d3.select(".gradient")
        .append("span")
        .attr('class', "grad-step")
        .style("background-color", colorScale(i));
}

var svg = d3.select("svg")
    .attr("width", '1200')
    .attr("height", '800')
    .attr('viewBox', '0 0 1200 800')
    .attr('preserveAspectRatio', 'xMinYMin');

// Define the div for the tooltip
var div = d3.select("body").append("div")
    .attr("class", "tooltip")
    .style("opacity", 0);

var counties = d3.json("resources/counties-with-population.geo.json");
var countiesVaccination = d3.json("resources/counties-vaccination.geo.json");
var districts = d3.json("resources/districts-with-population.geo.json");
var districtsVaccination = d3.json("resources/districts-vaccination.geo.json");

var render = function () {
    var admDivision = d3.select('#admDivisionSelect').node().value;
    var level = d3.select('#levelSelect').node().value;

    var promises = admDivision === 'county'
        ? [counties, countiesVaccination]
        : [districts, districtsVaccination];
    Promise.all(promises).then(function (arr) {
        var json = arr[0];
        var vaccination = arr[1];
        console.log("draw")
        json.features.forEach(function (feature) {
            feature.geometry = turf.rewind(feature.geometry, {reverse: true});
        })

        var projection = d3.geoMercator()
            .fitSize([svg.attr("width"), svg.attr("height")], json);

        var path = d3.geoPath()
            .projection(projection);

        svg.selectAll("path")
            .remove();

        svg.selectAll("path")
            .data(json.features)
            .enter()
            .append("path")
            .attr("d", path)
            .style("fill", function (geoUnit) {
                var vacInUnit = vaccination[geoUnit.properties.ref];
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
            })
            .on("mouseover", function (event, geoUnit) {
                var vacInUnit = vaccination[geoUnit.properties.ref];

                if (!vacInUnit) {
                    console.log(geoUnit.properties)
                    return;
                }

                div.transition()
                    .duration(200)
                    .style("opacity", .9);
                div.html(`
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
            })
            .on("mouseout", function () {
                div.transition()
                    .duration(500)
                    .style("opacity", 0);
            });
    });
}

d3.select('svg')
    .on('resize', render);

d3.select('#admDivisionSelect')
    .on('change', render);

d3.select('#levelSelect')
    .on('change', render);

render();
