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

R2.FormWithMemberSearch = function () {
    var search_div = $("member-search");

    if ( ! search_div ) {
        return;
    }

    this.form = R2.Utils.firstParentWithTagName( search_div, "FORM" );
    this.uri = $("member-search-uri").value;
    this.results = $("member-search-results");
    this.selected = $("member-search-selected");

    this._instrumentResultsClose();
    this._instrumentMemberSearch();
};

R2.FormWithMemberSearch.prototype._instrumentResultsClose = function () {
    DOM.Events.addListener( $("member-search-results-close"),
                            "click",
                            function (e) {
                                e.preventDefault();
                                if ( e.stopPropogation ) {
                                    e.stopPropagation();
                                }

                                this._hideResults();
                            }
                          );
};

R2.FormWithMemberSearch.prototype._instrumentMemberSearch = function () {
    new R2.FormWidget.AjaxSearch( this.uri,
                                  "member",
                                  this._onSearchSubmit(),
                                  this._handleEmptySubmit(),
                                  this._populateResults(),
                                  this._handleError()
                                );
};

R2.FormWithMemberSearch.prototype._onSearchSubmit = function () {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results, [ "member-search-results-close" ] );
        self.results.appendChild( document.createTextNode("Searching ...") );

        self.results.style.opacity = 0;
        DOM.Element.show( self.results );

        Animation.Fade.fade( { "elementId":     self.results.id,
                               "targetOpacity": 1 } );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._populateResults = function (results) {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results, [ "member-search-results-close" ] );

        if ( results.length > 0 ) {
            var text = "Found " + results.length;
            text += results.length == 1 ? " match:" : " matches:";

            self.results.appendChild( document.createTextNode(text) );

            var table = self._createResultsTable();
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
                                        self._makeAddFunction( tr, results[i], position )
                                      );

                DOM.Events.addListener( position,
                                        "keypress",
                                        self._makePositionEnterFunction(adder)
                                      );

                adder_td.appendChild(adder);

                tr.appendChild(adder_td);

                table.appendChild(tr);
            }

            self.results.appendChild(table);
        }
        else {
            self.results.appendChild( document.createTextNode("No people found that matched your search.") );
        }

        DOM.Element.show( self.results );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._createResultsTable = function () {
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

R2.FormWithMemberSearch.prototype._makeAddFunction = function ( tr, res, pos ) {
    var results_tr = tr;
    var result     = res;
    var position   = pos;

    var self = this;
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
            self._hideResults();
        }

        self._appendResult( result, position.value );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._makePositionEnterFunction = function (button) {
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

R2.FormWithMemberSearch.prototype._appendResult = function ( result, position_name ) {
    var empty = $( "member-search-empty" );

    if (empty) {
        empty.parentNode.removeChild(empty);
    }

    var table = $( "member-search-selected-table" );
    if ( ! table ) {
        table = this._createResultsTable();
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
                            this._makeRemoveFunction( tr, result )
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

    this.form.appendChild(person_id);
    this.form.appendChild(position);

    if ( table.style.opacity == 0 ) {
        this.selected.appendChild(table);
    }

    Animation.Fade.fade( { "elementId":     ( table.style.opacity == 0 ? table.id : tr.id ),
                           "targetOpacity": 1 } );
};

R2.FormWithMemberSearch.prototype._makeRemoveFunction = function ( tr, result ) {
    var selected_tr = tr;
    var res = result;

    var self = this;
    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        Animation.Fade.fade( { "elementId":     tr.id,
                               "targetOpacity": 0,
                               "onFinish":
                               function () { self._removeSelectedTr(tr); } } );

        var hidden = DOM.Find.getElementsByAttributes( { tagName:   "INPUT",
                                                         type:      "hidden",
                                                         name:      "person_id",
                                                         value:     res.person_id },
                                                       self.form );

        if ( hidden.length ) {
            hidden[0].parentNode.removeChild( hidden[0] );
        }
    };

    return func;
};

R2.FormWithMemberSearch.prototype._removeSelectedTr = function (tr) {
    var table = tr.parentNode;
    table.removeChild(tr);

    var other_tr = DOM.Find.getElementsByAttributes( { tagName:   "TR" },
                                                     table );

    if ( other_tr.length == 1 ) {
        table.parentNode.removeChild(table);
        this._addEmptyResultsP();
    }
};

R2.FormWithMemberSearch.prototype._addEmptyResultsP = function () {
    var p = document.createElement("p");
    p.appendChild( document.createTextNode("No members yet") );
    p.id = "member-search-empty";

    this.selected.appendChild(p);
};

R2.FormWithMemberSearch.prototype._hideResults = function () {
    this.results.style.opacity = 1;

    var results = this.results;
    Animation.Fade.fade( { "elementId":     this.results.id,
                           "targetOpacity": 0,
                           "onFinish":
                           function () { DOM.Element.hide(results); } }
                       );
};

R2.FormWithMemberSearch.prototype._handleEmptySubmit = function () {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results, [ "member-search-results-close" ] );

        var text = "You must provide a name to search for.";
        self.results.appendChild( document.createTextNode(text) );

        DOM.Element.show( self.results );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._handleError = function (results) {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results, [ "member-search-results-close" ] );

        var text = "An error occurred when searching for matching people."
        text += " Sometimes self error is temporary, so feel free to try again."
        text += " If self error persists, please contact support.";

        self.results.appendChild( document.createTextNode(text) );
    };

    return func;
};
