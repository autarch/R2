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
    this.results_div = $("member-search-results");
    this.selected = $("member-search-selected");
    this.person_ids = {};

    this._instrumentResultsClose();
    this._instrumentMemberSearch();
};

R2.FormWithMemberSearch.prototype._instrumentResultsClose = function () {
    var self = this;

    DOM.Events.addListener( $("member-search-results-close"),
                            "click",
                            function (e) {
                                e.preventDefault();
                                if ( e.stopPropogation ) {
                                    e.stopPropagation();
                                }

                                self._hideResults();
                            }
                          );
};

R2.FormWithMemberSearch.prototype._instrumentMemberSearch = function () {
    new R2.FormWidget.AjaxSearch( this.uri,
                                  "member",
                                  this._onSearchSubmitFunction(),
                                  this._handleEmptySubmitFunction(),
                                  this._populateResultsFunction(),
                                  this._handleErrorFunction()
                                );
};

R2.FormWithMemberSearch.prototype._onSearchSubmitFunction = function () {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results_div, [ "member-search-results-close" ] );
        self.results_div.appendChild( document.createTextNode("Searching ...") );

        self.results_div.style.opacity = 0;
        DOM.Element.show( self.results_div );

        Animation.Fade.fade( { "elementId":     self.results_div.id,
                               "targetOpacity": 1 } );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._populateResultsFunction = function () {
    var self = this;

    var func = function (results) {
        R2.Utils.cleanNode( self.results_div, [ "member-search-results-close" ] );

        if ( results.length > 0 ) {
            var text = "Found " + results.length;
            text += results.length == 1 ? " match:" : " matches:";

            self.results_div.appendChild( document.createTextNode(text) );

            var table = self._createResultsTable();
            table.id = "member-search-results-table";

            for ( var i = 0; i < results.length; i++ ) {
                var tr = self._createResultRow( results[i] );

                table.appendChild(tr);
            }

            self.results_div.appendChild(table);
        }
        else {
            self.results_div.appendChild( document.createTextNode("No people found that matched your search.") );
        }

        DOM.Element.show( self.results_div );
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

R2.FormWithMemberSearch.prototype._createResultRow = function (result) {
    var tr = document.createElement("tr");

    var id = R2.Utils.makeUniqueId();
    result.id = id;

    var name_td = document.createElement("td");
    name_td.appendChild( document.createTextNode( result.name ) );
    name_td.className = "name";

    tr.appendChild(name_td);

    if ( this.person_ids[ result.person_id ] ) {
        var already_td = document.createElement("td");
        already_td.colSpan = 2;
        already_td.appendChild( document.createTextNode("Already a member") );

        tr.appendChild(already_td);
    }
    else {
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
                                this._addMemberFunction( tr, result, position )
                              );

        DOM.Events.addListener( position,
                                "keypress",
                                this._positionEnterFunction(adder)
                              );

        adder_td.appendChild(adder);

        tr.appendChild(adder_td);
    }

    return tr;
};

R2.FormWithMemberSearch.prototype._addMemberFunction = function ( tr, res, pos ) {
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

R2.FormWithMemberSearch.prototype._positionEnterFunction = function (button) {
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
                            this.removeMemberFunction( tr, result )
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

    this.person_ids[ result.person_id ] = 1;

    Animation.Fade.fade( { "elementId":     ( table.style.opacity == 0 ? table.id : tr.id ),
                           "targetOpacity": 1 } );
};

R2.FormWithMemberSearch.prototype.removeMemberFunction = function ( tr, result ) {
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
    this.results_div.style.opacity = 1;

    var results = this.results_div;
    Animation.Fade.fade( { "elementId":     this.results_div.id,
                           "targetOpacity": 0,
                           "onFinish":
                           function () { DOM.Element.hide(results); } }
                       );
};

R2.FormWithMemberSearch.prototype._handleEmptySubmitFunction = function () {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results_div, [ "member-search-results-close" ] );

        var text = "You must provide a name to search for.";
        self.results_div.appendChild( document.createTextNode(text) );

        DOM.Element.show( self.results_div );
    };

    return func;
};

R2.FormWithMemberSearch.prototype._handleErrorFunction = function (results) {
    var self = this;

    var func = function () {
        R2.Utils.cleanNode( self.results_div, [ "member-search-results-close" ] );

        var text = "An error occurred when searching for matching people."
        text += " Sometimes self error is temporary, so feel free to try again."
        text += " If self error persists, please contact support.";

        self.results_div.appendChild( document.createTextNode(text) );
    };

    return func;
};
