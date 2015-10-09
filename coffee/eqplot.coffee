$(document).ready ->
    options =
        # canvas id
        id: ""
        # input tree
        treestring: ""
        # optional inputs
        labelcolors: ""
        labelscales: ""
        equallength: true
        # default values
        default:
            label_fontsize: 2
            label_color: "#484848"
            label_offset: 1.2
            edge_width: 0.3
            edge_color: "#fec44f"
            edge_scale: 1

    default_options_string = JSON.stringify(options, null, "\t")

    reset_options = ->
        options = JSON.parse(default_options_string)

    # main plot function
    plotPhylogeny = (options)->
        {label_fontsize, label_color, label_offset, edge_width, edge_color, edge_scale} = options.default

        # parser functions
        parse_input = (s)->
            s = s.replace(/\s/g,"")
            d = {}
            if s != ""
                s.split(",").map (e)-> [k,v]=e.split(":"); d[k] = v
            d

        parse_labelcolors = parse_input

        parse_labelscales = (s)->
            d = parse_input(s)
            for k, v of d
                f = parseFloat(v)
                if isNaN(f) or f <= 0
                    throw "Invalid label-scale: #{v}"
                d[k] = f
            d

        # setup canvas
        svg = d3.select("\##{options.id}")
            .append("svg")
            .attr("xmlns", "http://www.w3.org/2000/svg") #for download
            .attr("preserveAspectRatio", "xMinYMin meet")
            
        # compute locations
        if options.equallength
            tree = equal_angle(options.treestring, 8*edge_scale, true)
        else
            tree = equal_angle(options.treestring, 100*edge_scale, false)
        # the list of nodes
        nl = tree.postToList()
        
        # get optional colors and scales
        labelcolors = parse_labelcolors(options.labelcolors)
        labelscales = parse_labelscales(options.labelscales)

        # setup a temporary text object
        tmp = svg.append("text")

        get_text_size = (string, fontsize)->
            tmp.text(string).attr("font-size", fontsize)
            {width, height} = tmp[0][0].getBoundingClientRect()
            [width, height]

        nodes = []
        edges = []
        labels = []
        for n in nl
            if not n.isRoot()
                [x, y] = n.loc
                [fx, fy] = n.father.loc
                edges.push([{x:x,y:y},{x:fx,y:fy}])

                if n.name? and n.name != ""
                    fontsize = label_fontsize*(labelscales[n.name] or 1)
                    color = labelcolors[n.name] or label_color
                    [width, height] = get_text_size(n.name, fontsize)
                    labels.push
                        x:x, y:y
                        # lx, ly: x, y of labels
                        lx: fx + (x-fx)*label_offset
                        ly: fy + (y-fy)*label_offset
                        name: n.name
                        width: width
                        height: height
                        fontsize: fontsize
                        color: color

        tmp.remove()

        # try to resolve overlaps
        resolve = (a, b)->
            l1 = a.lx - a.width/2
            r1 = a.lx + a.width/2
            l2 = b.lx - b.width/2
            r2 = b.lx + b.width/2
            
            if r1 < l2 or r2 < l1
                return

            t1 = a.ly - a.height/3
            b1 = a.ly + a.height/3
            t2 = b.ly - b.height/3
            b2 = b.ly + b.height/3

            if b1 <= t2 or b2 <= t1
                return

            if a.x <= b.x
                hori_overlap = r1-l2
            else
                hori_overlap = r2-l1

            if a.y <= b.y
                vert_overlap = b1-t2
            else
                vert_overlap = b2-t1

            if hori_overlap/(a.width+b.width) < vert_overlap/(a.height+b.height)
                if a.x <= b.x
                    a.lx -= hori_overlap/2
                    b.lx += hori_overlap/2
                else
                    a.lx += hori_overlap/2
                    b.lx -= hori_overlap/2
            else
                if a.y <= b.y
                    a.ly -= vert_overlap/2
                    b.ly += vert_overlap/2
                else
                    a.ly += vert_overlap/2
                    b.ly -= vert_overlap/2

        # reslove twice
        for a, i in labels
            for b, j in labels
                if i!=j
                    resolve(a, b)
        for a, i in labels
            for b, j in labels
                if i!=j
                    resolve(a, b)

        # setup drag behavior
        dragmove = (d)->
            d3.select(this)
                .attr("x", d3.event.x)
                .attr("y", d3.event.y)
        drag = d3.behavior.drag().on("drag", dragmove)

        # no line styles
        line = d3.svg.line()
            .x((d)-> d.x)
            .y((d)-> d.y)
    
        # plot edges
        _edges = svg.append("g")
            .selectAll("path")
            .data(edges)
            .enter()
            .append("path")
            .attr("d", (d) -> line(d))
            .attr("stroke-width", edge_width)
            .attr("stroke", edge_color)
            .attr("stroke-linejoin","round")
            .attr("stroke-linecap","round")
       
        # plot labels
        _labels = svg.append("g")
            .selectAll("text")
            .data(labels)
            .enter().append("text")
            .attr("x", (d)->d.lx)
            .attr("y", (d)->d.ly)
            .attr('dy','0.35em')
            .attr("text-anchor", "middle")
            .attr("font-size", (d)->d.fontsize)
            .attr("fill", (d)->d.color)
            .text((d) -> d.name)
            .call(drag)

        pad = 5
        # center the plot
        bbox = svg[0][0].getBBox()
        {x, y, width, height} = bbox
        svg.selectAll("g")
            .attr("transform", "translate(#{pad-x},#{pad-y})")

        # set viewbox
        outwidth = $("#tp").parent().width()*0.95
        outheight = outwidth/width*height
        svg.attr("viewBox", "0 0 #{width+2*pad} #{height+2*pad}")
        svg.attr("width", outwidth)
        svg.attr("height", outheight)

    ######################################################################
    load_options = ()->
        options.id = "tp"
        options.treestring = $("#ts").val()
        options.labelcolors = $("#tc").val()
        options.labelscales = $("#tf").val()
        options.equallength = $("#eq").is(":checked")
        try
            options_string = $("#op").val()
            options.default = JSON.parse(options_string)

    doplot = ->
        $("#tp").html("")
        try
            load_options()
            plotPhylogeny(options)
<<<<<<< HEAD
=======
            $("#plot").get(0).scrollIntoView()
>>>>>>> master
            $("#te").hide()
        catch error
            console.log error
            $("#te").html(String(error))
            $("#te").show()
        
    saveplot = ->
        _svg = d3.select("svg")[0][0]
        svg_string = document.getElementById("tp").innerHTML
        blob = new Blob([svg_string], {type: "image/svg+xml;base64"})
        saveAs(blob, "plot.svg")
    
    clear = ->
        $("#ts").val("")
        $("#tc").val("")
        $("#tf").val("")
        $("#tp").html("")
        reset_options()
        options_string = JSON.stringify(options.default, null, '\t')
        $("#op").val(options_string)

    $("#plot").click doplot
    $("#clear").click clear
    $("#save").click saveplot
    $("#ad").click ->
        try
            options_string = $("#op").val()
            options.default = JSON.parse(options_string)
        options_string = JSON.stringify(options.default, null, '\t')
        $("#op").val(options_string)
        $("#op").toggle()

    $("#example").click ->
        treestring = "(coalescence:0.045993038,deep:0.04624504,(cost:0.23139237,(duplication:0.3638669,(((gene:0.19954431,loss:0.20143054):0.1701682,lineage:0.37318188):0.034821946,(number:0.42671138,(((((rf:0.10377345,distance:0.10017748):0.23562986,equivalent:0.33383065):0.057406668,relationships:0.38811886):0.03425868,((reconciliation:0.23132662,costs:0.24479628):0.1233465,methods:0.3576585):0.0694008):0.022499183,((((((species:0.23725139,tree:0.23160231):0.036646213,space:0.270384):0.12870727,(trees:0.3850207,score:0.37763426):0.020136086):0.0419018,(defined:0.38267758,((terraces:0.2684868,size:0.26890138):0.035748273,distribution:0.30611905):0.079874806):0.05296954):0.011245258,furnas:0.4482118):0.0048618168,(implies:0.45888194,(((((assume:0.41579154,child:0.41677946):0.0234262,descendant:0.44509086):0.0077592554,((root:0.37822682,path:0.3830252):0.028375672,mapped:0.39903435):0.037732556):0.0014083103,((case:0.4295289,(lemma:0.3685342,proof:0.36388388):0.0678121):0.016068572,(leaf:0.39813396,children:0.3906566):0.049809817):0.0051155305):0.006810868,((((lca:0.28116992,map:0.27778623):0.15751457,(leaves:0.39113843,denotes:0.39502105):0.03147065):0.015321414,((subtree:0.26571432,left:0.2632676):0.17959024,fig:0.44388893):0.0022803498):0.00667195,(((node:0.2857698,nonroot:0.29209435):0.11268219,((nodes:0.27586785,internal:0.26188087):0.08705686,binary:0.35139877):0.050516304):0.032112896,cluster:0.44481996):0.014393961):0.0016197097):0.0032334558):0.0069535444):0.008581441):0.023296922):0.019111378):0.03873653):0.13201661):0.19112077);"
        labelcolors = "lca:red, proof:blue, leaf:#6d4, fig:#3182bd"
        labelscales = "rf:3, lca:2, case:1.5, left:0.7"

        $("#ts").val(treestring)
        $("#tc").val(labelcolors)
        $("#tf").val(labelscales)
