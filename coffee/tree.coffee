# Node 
class Node
    constructor : ->
        @name = ""
        @children = []

    addChild : (child = new Node) ->
        @children.push child
        child.father = @
        child

    isLeaf : ->
        @children.length == 0

    isRoot : ->
        (not @father?) or (@father == null)

    string: ->
        s = "#{@name}#{if @length? then ":"+@length else ""}"
        if @children.length > 0
            "(#{(c.string() for c in @children).join(",")})#{s}"
        else
            s

    show : ->
        console.log "#{@string()};"

    postToList : (l=[]) ->
        for child in @children
            child.postToList(l)
        l.push @
        return l

# make tree from Newick format, return the root of the tree.
Tree = (s) ->
    #token = s.replace(/\s+/g, "").match(/[\(\),;:]|[^\(\),;:\s]+/g)
    token = String(s).match(/[\(\),;:]|[^\(\),;:\s]+/g)
    if not token? or token.length == 0
        throw "Invalid tree."
    tree = node = new Node
    flag = false
    for item in token
        switch item
            when "("
                [node, flag] = [node.addChild(), false]
            when ")"
                throw "Invalid Tree: #{s}" unless node.father?
                [node, flag] = [node.father, false]
            when ","
                throw "Invalid Tree: #{s}" unless node.father?
                [node, flag] = [node.father.addChild(), false]
            when ":"
                flag = true
            when ";"
                break
            else
                if flag
                    if isNaN node.length = parseFloat(item)
                        throw "Invalid branch length: #{item}"
                else
                    node.name = item
                flag = false

    if tree != node then throw "Invalid Tree: #{s}"
    return tree

# compute the equal_angle layout
equal_angle = (tree_string, length_scale, equal_length) ->
    tree = Tree(tree_string)

    postlist = tree.postToList()

    for n, i in postlist
        if n.isLeaf()
            n.numOfLeaves = 1
        else
            n.numOfLeaves = 0
            for c in n.children
                n.numOfLeaves += c.numOfLeaves

    move_along = (loc, direction, length) ->
        [x, y] = loc
        x += Math.cos(direction) * length
        y += Math.sin(direction) * length
        [x, y]

    tree.angle = [0, Math.PI] #[left_angle, direction]
    tree.loc = [0, 0]

    for i in [postlist.length-1..0]
        n = postlist[i]
        total_angle = (n.angle[1] - n.angle[0])*2
        present_langle = n.angle[0]
        for c in n.children
            angle = total_angle * c.numOfLeaves / n.numOfLeaves
            c.angle = [present_langle, present_langle + angle/2]
            if equal_length
                length = length_scale
            else
                length = c.length * length_scale
            c.loc = move_along(n.loc, c.angle[1], length)
            present_langle = present_langle + angle
    tree

root = global ? window
root.equal_angle = equal_angle
