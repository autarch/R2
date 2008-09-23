JSAN.use('Animation.Fade');
JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.AjaxSearch');
JSAN.use('R2.Utils');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.HouseholdForm == "undefined" ) {
    R2.HouseholdForm = {};
}

R2.HouseholdForm.instrumentForm = function () {
    var form = $("household-form");

    if ( ! form ) {
        return;
    }

    R2.HouseholdForm.form = form;
    R2.HouseholdForm.results = $("member-search-results");
    R2.HouseholdForm.selected = $("member-search-selected");

    R2.HouseholdForm._instrumentResultsClose();
    R2.HouseholdForm._instrumentMemberSearch();
};

R2.HouseholdForm._instrumentResultsClose = function () {
    DOM.Events.addListener( $("member-search-results-close"),
                            "click",
                            function (e) {
                                e.preventDefault();
                                if ( e.stopPropogation ) {
                                    e.stopPropagation();
                                }

                                R2.HouseholdForm._hideResults();
                            }
                          );
};

R2.HouseholdForm._instrumentMemberSearch = function () {
    var search =
        new R2.FormWidget.AjaxSearch( "/person",
                                      "member",
                                      R2.HouseholdForm._onSearchSubmit,
                                      R2.HouseholdForm._handleEmptySubmit,
                                      R2.HouseholdForm._populateResults,
                                      R2.HouseholdForm._handleError
                                    );

};

R2.HouseholdForm._onSearchSubmit = function () {
    R2.Utils.cleanNode( R2.HouseholdForm.results, [ "member-search-results-close" ] );
    R2.HouseholdForm.results.appendChild( document.createTextNode("Searching ...") );

    R2.HouseholdForm.results.style.opacity = 1;
    DOM.Element.show( R2.HouseholdForm.results );
};

R2.HouseholdForm._populateResults = function (results) {
    R2.Utils.cleanNode( R2.HouseholdForm.results, [ "member-search-results-close" ] );

    if ( results.length > 0 ) {
        var text = "Found " + results.length;
        text += results.length == 1 ? " match:" : " matches:";

        R2.HouseholdForm.results.appendChild( document.createTextNode(text) );

        var table = R2.HouseholdForm._createResultsTable();
        table.id = "member-search-results-table";

        for ( var i = 0; i < results.length; i++ ) {
            var tr = document.createElement("tr");

            var id = R2.Utils.makeUniqueId();
            results[i].id = id;

            var name_td = document.createElement("td");
            name_td.appendChild( document.createTextNode( results[i].name ) );
            name_td.className = "name";

            tr.appendChild(name_td);

            var position_td = document.createElement("td");
            position_td.className = "position";
            var position = document.createElement("input");
            position.type = "text";
            position.name = "position-for-" + id;
            position.className = "text";

            position_td.appendChild(position);

            tr.appendChild(position_td);

            var adder_td = document.createElement("td");
            adder_td.className = "button";
            var adder = document.createElement("button");
            adder.type = "button";
            adder.appendChild( document.createTextNode("add") );
            adder.id = "adder-" + id;

            DOM.Events.addListener( adder,
                                    "click",
                                    R2.HouseholdForm._makeAddFunction( tr, results[i], position )
                                  );

            DOM.Events.addListener( position,
                                    "keypress",
                                    R2.HouseholdForm._makePositionEnterFunction(adder)
                                  );

            adder_td.appendChild(adder);

            tr.appendChild(adder_td);

            table.appendChild(tr);
        }

        R2.HouseholdForm.results.appendChild(table);
    }
    else {
        R2.HouseholdForm.results.appendChild( document.createTextNode("No people found that matched your search.") );
    }

    DOM.Element.show( R2.HouseholdForm.results );
};

R2.HouseholdForm._createResultsTable = function () {
    var table = document.createElement("table");

    var thead = document.createElement("thead");

    var tr = document.createElement("tr");

    var name_th = document.createElement("th");
    name_th.appendChild( document.createTextNode("Name") );
    name_th.className = "name";

    tr.appendChild(name_th);

    var position_th = document.createElement("th");
    position_th.appendChild( document.createTextNode("Position") );
    position_th.className = "position";

    tr.appendChild(position_th);

    var button_th = document.createElement("th");
    button_th.className = "button";

    tr.appendChild(button_th);

    thead.appendChild(tr);

    table.appendChild(thead);

    table.appendChild( document.createElement("tbody") );

    return table;
};

R2.HouseholdForm._makeAddFunction = function ( tr, res, pos ) {
    var results_tr = tr;
    var result     = res;
    var position   = pos;

    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        var parent = results_tr.parentNode;
        parent.removeChild(results_tr);

        var other_tr = DOM.Find.getElementsByAttributes( { tagName:   "TR" },
                                                         parent );

        if ( other_tr.length == 1 ) {
            R2.HouseholdForm._hideResults();
        }

        R2.HouseholdForm._appendResult( result, position.value );
    };

    return func;
};

R2.HouseholdForm._makePositionEnterFunction = function (button) {
    var adder = button;

    var func = function (e) {
        if ( e.keyCode != 13 ) {
            return e.keyCode;
        }

        adder.click();

        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }
    };

    return func;
}

R2.HouseholdForm._appendResult = function ( result, position_name ) {
    var empty = $( "member-search-empty" );

    if (empty) {
        empty.parentNode.removeChild(empty);
    }

    var table = $( "member-search-selected-table" );
    if ( ! table ) {
        table = R2.HouseholdForm._createResultsTable();
        table.id = "member-search-selected-table";
        table.style.opacity = 0;
    }

    var tr = document.createElement("tr");
    tr.id = R2.Utils.makeUniqueId();
    tr.style.opacity = table.style.opacity == 0 ? 1 : 0;

    var name_td = document.createElement("td");
    name_td.className = "name";
    name_td.appendChild( document.createTextNode( result.name ) );

    tr.appendChild(name_td);

    var position_td = document.createElement("td");
    position_td.className = "position";
    position_td.appendChild
        ( document.createTextNode( typeof position_name != "undefined" ? position_name : "" ) );

    tr.appendChild(position_td);

    var remover_td = document.createElement("td");
    remover_td.className = "button";
    var remover = document.createElement("button");
    remover.type = "button";
    remover.appendChild( document.createTextNode("remove") );

    tr.appendChild(remover_td);

    DOM.Events.addListener( remover,
                            "click",
                            R2.HouseholdForm._makeRemoveFunction( tr, result )
                          );

    remover_td.appendChild(remover);

    table.appendChild(tr);

    var person_id = document.createElement("input");
    person_id.type = "hidden";
    person_id.name = "person_id-" + result.id;
    person_id.value = result.person_id;

    var position = document.createElement("input");
    position.type = "hidden";
    position.name = "position-" + result.id;
    position.value = position_name;

    R2.HouseholdForm.form.appendChild(person_id);
    R2.HouseholdForm.form.appendChild(position);

    if ( table.style.opacity == 0 ) {
        R2.HouseholdForm.selected.appendChild(table);
    }

    Animation.Fade.fade( { "elementId":     ( table.style.opacity == 0 ? table.id : tr.id ),
                           "targetOpacity": 1 } );
};

R2.HouseholdForm._makeRemoveFunction = function ( tr, result ) {
    var selected_tr = tr;
    var res = result;

    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        Animation.Fade.fade( { "elementId":     tr.id,
                               "targetOpacity": 0,
                               "onFinish":
                               function () { R2.HouseholdForm._removeSelectedTr(tr); } } );

        var hidden = DOM.Find.getElementsByAttributes( { tagName:   "INPUT",
                                                         type:      "hidden",
                                                         name:      "person_id",
                                                         value:     res.person_id },
                                                       R2.HouseholdForm.form );

        if ( hidden.length ) {
            hidden[0].parentNode.removeChild( hidden[0] );
        }
    };

    return func;
};

R2.HouseholdForm._removeSelectedTr = function (tr) {
    var table = tr.parentNode;
    table.removeChild(tr);

    var other_tr = DOM.Find.getElementsByAttributes( { tagName:   "TR" },
                                                     table );

    if ( other_tr.length == 1 ) {
        table.parentNode.removeChild(table);
        R2.HouseholdForm._addEmptyResultsP();
    }
};

R2.HouseholdForm._addEmptyResultsP = function () {
    var p = document.createElement("p");
    p.appendChild( document.createTextNode("No members yet") );
    p.id = "member-search-empty";

    R2.HouseholdForm.selected.appendChild(p);
};

R2.HouseholdForm._hideResults = function () {
    R2.HouseholdForm.results.style.opacity = 1;

    Animation.Fade.fade( { "elementId":     R2.HouseholdForm.results.id,
                           "targetOpacity": 0,
                           "onFinish":
                           function () { DOM.Element.hide( R2.HouseholdForm.results ); } }
                       );
};

R2.HouseholdForm._handleEmptySubmit = function () {
    R2.Utils.cleanNode( R2.HouseholdForm.results, [ "member-search-results-close" ] );

    var text = "You must provide a name to search for.";
    R2.HouseholdForm.results.appendChild( document.createTextNode(text) );

    DOM.Element.show( R2.HouseholdForm.results );
};

R2.HouseholdForm._handleError = function (results) {
    R2.Utils.cleanNode( R2.HouseholdForm.results, [ "member-search-results-close" ] );

    var text = "An error occurred when searching for matching people."
    text += " Sometimes this error is temporary, so feel free to try again."
    text += " If this error persists, please contact support.";

    R2.HouseholdForm.results.appendChild( document.createTextNode(text) );
};
