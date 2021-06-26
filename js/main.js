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

var counties = d3.json("resources/counties.geo.json");
var districts = d3.json("resources/districts.geo.json");

var render = function () {
    var admDivision = d3.select('#admDivisionSelect').node().value;
    var level = d3.select('#levelSelect').node().value;

    var geo = admDivision === 'county' ? counties : districts;
    geo.then(function (json) {
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
                var percentage;
                switch (level) {
                    case 'fully':
                        percentage = geoUnit.properties.fullyVaccinated / geoUnit.properties.population * 100;
                        break;
                    case 'atLeastOne':
                        percentage = geoUnit.properties.atLeastOneDose / geoUnit.properties.population * 100;
                        break;
                    case '12_19':
                        percentage = geoUnit.properties.w1_12_19 / geoUnit.properties["12_19"] * 100;
                        break;
                    case '20_39':
                        percentage = geoUnit.properties.w1_20_39 / geoUnit.properties["20_39"] * 100;
                        break;
                    case '40_59':
                        percentage = geoUnit.properties.w1_40_59 / geoUnit.properties["40_59"] * 100;
                        break;
                    case '60_69':
                        percentage = geoUnit.properties.w1_60_69 / geoUnit.properties["60_69"] * 100;
                        break;
                    case '70plus':
                        percentage = geoUnit.properties.w1_70plus / geoUnit.properties["70plus"] * 100;
                        break;
                    default:
                        percentage = 0;
                }
                return colorScale(percentage);
            })
            .on("mouseover", function (event, geoUnit) {
                div.transition()
                    .duration(200)
                    .style("opacity", .9);
                div.html(`
                <p><strong>${geoUnit.properties.name}</strong></p>
                <p>Zaszczepieni: ${(geoUnit.properties.fullyVaccinated * 100.0 / geoUnit.properties.population).toFixed(1)}% (${geoUnit.properties.fullyVaccinated}/${geoUnit.properties.population})</p>
                <p>Co najmniej jedną: ${(geoUnit.properties.atLeastOneDose * 100.0 / geoUnit.properties.population).toFixed(1)}% (${geoUnit.properties.atLeastOneDose}/${geoUnit.properties.population})</p>
                <p>12-19: ~${(geoUnit.properties.w1_12_19 * 100.0 / geoUnit.properties["12_19"]).toFixed(1)}% (${geoUnit.properties.w1_12_19}/~${geoUnit.properties["12_19"]})</p>
                <p>20-39: ${(geoUnit.properties.w1_20_39 * 100.0 / geoUnit.properties["20_39"]).toFixed(1)}% (${geoUnit.properties.w1_20_39}/${geoUnit.properties["20_39"]})</p>
                <p>40-59: ${(geoUnit.properties.w1_40_59 * 100.0 / geoUnit.properties["40_59"]).toFixed(1)}% (${geoUnit.properties.w1_40_59}/${geoUnit.properties["40_59"]})</p>
                <p>60-69: ${(geoUnit.properties.w1_60_69 * 100.0 / geoUnit.properties["60_69"]).toFixed(1)}% (${geoUnit.properties.w1_60_69}/${geoUnit.properties["60_69"]})</p>
                <p>70plus: ${(geoUnit.properties.w1_70plus * 100.0 / geoUnit.properties["70plus"]).toFixed(1)}% (${geoUnit.properties.w1_70plus}/${geoUnit.properties["70plus"]})</p>
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
