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

        var ul = document.createElement("ul");

        for ( var i = 0; i < results.length; i++ ) {
            var li = document.createElement("li");
            li.appendChild( document.createTextNode( results[i].name ) );
            li.id = R2.Utils.makeUniqueId();
            li.style.opacity = 1;

            var adder = document.createElement("button");
            adder.type = "button";
            adder.appendChild( document.createTextNode("add") );

            DOM.Events.addListener( adder,
                                    "click",
                                    R2.HouseholdForm._makeAddFunction( li, results[i] )
                                  );

            li.appendChild(adder);

            ul.appendChild(li);
        }

        R2.HouseholdForm.results.appendChild(ul);
    }
    else {
        R2.HouseholdForm.results.appendChild( document.createTextNode("No people found.") );
    }

    DOM.Element.show( R2.HouseholdForm.results );
};

R2.HouseholdForm._handleError = function (results) {
    R2.Utils.cleanNode( R2.HouseholdForm.results, [ "member-search-results-close" ] );

    var text = "An error occurred when searching for matching people."
    text += " Sometimes this error is temporary, so feel free to try again."
    text += " If this error persists, please contact support.";

    R2.HouseholdForm.results.appendChild( document.createTextNode(text) );
};

R2.HouseholdForm._makeAddFunction = function ( li, result ) {
    var res = result;

    var results_li = li;

    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        var parent = results_li.parentNode;
        parent.removeChild(results_li);

        if ( parent.childNodes.length == 0 ) {
            R2.HouseholdForm._hideResults();
        }

        R2.HouseholdForm._appendResult(result);
    };

    return func;
};

R2.HouseholdForm._appendResult = function (result) {
    var empty = $( "member-search-empty-list" );

    if (empty) {
        empty.parentNode.removeChild(empty);
    }

    var li = document.createElement("li");
    li.appendChild( document.createTextNode( result.name ) );
    li.id = R2.Utils.makeUniqueId();
    li.style.opacity = 0;

    var remover = document.createElement("button");
    remover.type = "button";
    remover.appendChild( document.createTextNode("remove") );

    DOM.Events.addListener( remover,
                            "click",
                            R2.HouseholdForm._makeRemoveFunction( li, result )
                          );

    li.appendChild(remover);

    var hidden = document.createElement("input");
    hidden.type = "hidden";
    hidden.name = "person_id";
    hidden.value = result.person_id;

    R2.HouseholdForm.form.appendChild(hidden);
    R2.HouseholdForm.selected.appendChild(li);

    Animation.Fade.fade( { "elementId":     li.id,
                           "targetOpacity": 1 } );
};

R2.HouseholdForm._makeRemoveFunction = function ( li, result ) {
    var selected_li = li;
    var res = result;

    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        Animation.Fade.fade( { "elementId":     li.id,
                               "targetOpacity": 0,
                               "onFinish":
                               function () { R2.HouseholdForm._removeSelectedLi(li); } } );

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

R2.HouseholdForm._removeSelectedLi = function (li) {
    li.parentNode.removeChild(li);
    var other_li = DOM.Find.getElementsByAttributes( { tagName:   "LI" },
                                                     R2.HouseholdForm.selected );

    if ( other_li.length == 0 ) {
        R2.HouseholdForm._addEmptyListLi();
    }
};

R2.HouseholdForm._addEmptyListLi = function () {
    var li = document.createElement("li");
    li.appendChild( document.createTextNode("No members yet") );
    li.id = "member-search-empty-list";

    R2.HouseholdForm.selected.appendChild(li);
};

R2.HouseholdForm._hideResults = function () {
    R2.HouseholdForm.results.style.opacity = 1;

    Animation.Fade.fade( { "elementId":     R2.HouseholdForm.results.id,
                           "targetOpacity": 0,
                           "onFinish":
                           function () { DOM.Element.hide( R2.HouseholdForm.results ); } }
                       );
}