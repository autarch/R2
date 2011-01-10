if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.Utils == "undefined" ) {
    R2.Utils = {};
}

R2.Utils.firstParentWithTagName = function ( child, tag_name ) {
    var node = child;

    while ( node = node.parentNode ) {
        if ( node.tagName == tag_name ) {
            return node;
        }
    }
};

R2.Utils.cleanNode = function ( node, except ) {
    if ( ! node ) {
        return;
    }

    var children = node.childNodes;

    if ( ! children.length ) {
        return;
    }

    var keep = {};
    if ( typeof except != "undefined" ) {
        for ( var i = 0; i < except.length; i++ ) {
            keep[ except[i] ] = true;
        }
    }

    var to_remove = [];

    /* If we remove the children while looking at this array's length,
       there is serious breakage. Apparently, childNodes is returning a
       reference, not a copy. */
    for ( var i = 0; i < children.length; i++ ) {
        if ( typeof children[i].id != "undefined"
             && keep[ children[i].id ] == true ) {

            continue;
        }

        to_remove.push( children[i] );
    }

    for ( var i = 0; i < to_remove.length; i++ ) {
        node.removeChild( to_remove[i] );
    }
};

R2.Utils._id_base = 0;
R2.Utils.makeUniqueId = function () {
    var id = "js-R2-Utils-" + R2.Utils._id_base;

    R2.Utils._id_base++;

    return id;
};
