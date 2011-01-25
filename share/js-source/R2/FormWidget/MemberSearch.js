JSAN.use('R2.FormWidget.AjaxSearch');
JSAN.use('R2.Utils');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.MemberSearch = function () {
    var search_div = $("#member-search");

    if ( ! search_div.length ) {
        return;
    }

    this.form        = search_div.closest("form");
    this.uri         = $("#member-search-uri").val();
    this.results_div = $("#member-search-results");
    this.selected    = $("#member-search-selected");
    this.person_ids  = {};

    this._instrumentExistingTable();
    this._instrumentResultsClose();
    this._instrumentMemberSearch();
};

R2.FormWidget.MemberSearch.prototype._instrumentExistingTable = function () {
    var table = $("#member-search-selected-table");

    if ( ! table.length ) {
        return;
    }

    var self = this;

    table.find("button").each(
        function () {
            var matches = $(this).attr("name").match( /remove-(\d+)/ );
            var person_id = matches[1];

            if ( ! person_id ) {
                return;
            }

            self.person_ids[person_id] = 1;

            var tr = $(this).closest("tr");

            tr.attr( "id", R2.Utils.makeUniqueId() );

            var result = { "person_id": person_id };
            var hidden_name = "person_id-existing-" + person_id;

            self._instrumentRemoveButton( $(this), tr, result, hidden_name );
        }
    );
};

R2.FormWidget.MemberSearch.prototype._instrumentResultsClose = function () {
    var self = this;

    $("#member-search-results-close").click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self._hideResults();
        }
    );
};

R2.FormWidget.MemberSearch.prototype._instrumentMemberSearch = function () {
    new R2.FormWidget.AjaxSearch(
        this.uri,
        "member",
        this._onSearchSubmitFunction(),
        this._handleEmptySubmitFunction(),
        this._populateResultsFunction(),
        this._handleErrorFunction()
    );
};

R2.FormWidget.MemberSearch.prototype._onSearchSubmitFunction = function () {
    var self = this;

    var func = function () {
        self._cleanResultsDiv();

        self.results_div.append( document.createTextNode("Searching ...") );

        self.results_div.fadeIn(500);
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._populateResultsFunction = function () {
    var self = this;

    var func = function (results) {
        self._cleanResultsDiv();

        if ( results.length > 0 ) {
            var text = "Found " + results.length;
            text += results.length == 1 ? " match:" : " matches:";

            self.results_div.append( document.createTextNode(text) );

            var table = self._createResultsTable();
            table.addClass("ajax-search-results-table");
            table.attr( "id", "member-search-results-table" );

            for ( var i = 0; i < results.length; i++ ) {
                var tr = self._createResultRow( results[i] );

                table.append(tr);
            }

            self.results_div.append(table);
        }
        else {
            self.results_div.append( document.createTextNode("No people found that matched your search.") );
        }

        self.results_div.fadeIn(500);
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._cleanResultsDiv = function () {
    this.results_div.contents().filter(
        function () {
            if ( $(this).attr("id") == "member-search-results-close"
                 || $(this).find("#member-search-results-close").length ) {
                return 0;
            }

            return 1;
        }
    ).remove();
};

R2.FormWidget.MemberSearch.prototype._createResultsTable = function () {
    var table = $("<table/>");

    var thead = $("<thead/>");

    var tr = $("<tr/>");

    var name_th = $("<th/>");
    name_th.append( document.createTextNode("Name") );
    name_th.addClass("name");

    tr.append(name_th);

    var position_th = $("<th/>");
    position_th.append( document.createTextNode("Position") );
    position_th.addClass("position");

    tr.append(position_th);

    var button_th = $("<th/>");
    button_th.addClass("button");

    tr.append(button_th);

    thead.append(tr);

    table.append(thead);

    table.append( $("<tbody/>") );

    return table;
};

R2.FormWidget.MemberSearch.prototype._createResultRow = function (result) {
    var tr = $("<tr/>");

    var id = R2.Utils.makeUniqueId();
    result.id = id;

    var name_td = $("<td/>");
    name_td.append( document.createTextNode( result.display_name ) );
    name_td.addClass(name);

    tr.append(name_td);

    if ( this.person_ids[ result.person_id ] ) {
        var already_td = $("<td/>");
        already_td.attr( "colspan", 2 );
        already_td.append( document.createTextNode("Already a member") );

        tr.append(already_td);
    }
    else {
        var position_td = $("<td/>");
        position_td.addClass("position");

        var position = $("<input/>");
        position.attr( "type", "text" );
        position.attr( "name", "position-for-" + id );
        position.addClass("text");

        position_td.append(position);

        tr.append(position_td);

        var adder_td = $("<td/>");
        adder_td.addClass("button");

        var adder = $("<button/>");
        adder.attr( "type", "button" );
        adder.attr( "id",   "adder-" + id );
        adder.append( document.createTextNode("add") );

        adder.click(
            this._addMemberFunction( tr, result, position )
        );

        position.keypress(
            this._positionEnterFunction(adder)
        );

        adder_td.append(adder);

        tr.append(adder_td);
    }

    return tr;
};

R2.FormWidget.MemberSearch.prototype._addMemberFunction = function ( tr, res, pos ) {
    var results_tr = tr;
    var result     = res;
    var position   = pos;

    var self = this;
    var func = function (e) {
        e.preventDefault();
        e.stopPropagation();

        results_tr.fadeOut(
            500,
            function () {
                var tbody = results_tr.closest("tbody");

                results_tr.detach();

                if ( tbody.find("tr").length == 0 ) {
                    self._hideResults();
                }

                self._appendResultToSelected( result, position.val() );
            }
        );
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._positionEnterFunction = function (button) {
    var adder = button;

    var func = function (e) {
        if ( e.which != 13 ) {
            return e.which;
        }

        adder.click();

        e.preventDefault();
        e.stopPropagation();
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._appendResultToSelected = function ( result, position_name ) {
    $("#member-search-empty").detach();

    var elt_to_fade;

    var table = $( "#member-search-selected-table" );
    var tbody;

    if ( table.length ) {
        var tbody = $( "tbody", table ).first();
    }
    else {
        table = this._createResultsTable();
        table.addClass("ajax-search-selected-table");
        table.attr( "id", "member-search-selected-table" );

        var tbody = $("<tbody/>");
        table.append(tbody);

        elt_to_fade = table;
    }

    var tr = $("<tr/>");
    tr.attr( "id", R2.Utils.makeUniqueId() );
    if ( ! elt_to_fade ) {
        elt_to_fade = tr;
    }

    var name_td = $("<td/>");
    name_td.addClass("name");
    name_td.append( document.createTextNode( result.display_name ) );

    tr.append(name_td);

    var position_td = $("<td/>");
    position_td.addClass("position");

    var position_input = $("<input/>");
    position_input.attr( "type",  "text" );
    position_input.attr( "name",  "position-" + result.id );
    position_input.attr( "value", typeof position_name != "undefined" ? position_name : "" );

    position_td.append(position_input);

    tr.append(position_td);

    var remover_td = $("<td/>");
    remover_td.addClass("button");
    var remover = $("<button/>");
    remover.attr( "type", "button" );
    remover.attr( "name", "remove-" + result.id );
    remover.append( document.createTextNode("remove") );

    tr.append(remover_td);

    remover_td.append(remover);

    tbody.append(tr);

    var person_id = $("<input/>");
    person_id.attr( "type",  "hidden" );
    person_id.attr( "name",  "person_id-" + result.id );
    person_id.attr( "value", result.person_id );

    this.form.append(person_id);

    this._instrumentRemoveButton( remover, tr, result, person_id.attr("name") );

    if ( ! table.parent().length ) {
        this.selected.append(table);
    }

    this.person_ids[ result.person_id ] = 1;

    elt_to_fade.fadeIn(500);
};

R2.FormWidget.MemberSearch.prototype._instrumentRemoveButton = function ( remover, tr, result, hidden_name ) {
    remover.click(
        this.removeMemberFunction( remover, tr, result, hidden_name )
    );
};

R2.FormWidget.MemberSearch.prototype.removeMemberFunction = function ( button, tr, result, hidden_name ) {
    var remover = button;
    var selected_tr = tr;
    var res = result;
    var input_name = hidden_name;

    var self = this;
    var func = function (e) {
        e.preventDefault();
        e.stopPropagation();

        remover.unbind();

        selected_tr.fadeOut(
            500,
            function () {
                self._removeSelectedTr(selected_tr);
            }
        );

        $( 'input:hidden[name="' + input_name + '"]', self.form ).detach();

        delete self.person_ids[ res.person_id ];
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._removeSelectedTr = function (tr) {
    var table = tr.closest("table");

    tr.closest("tbody").detach();

    if ( table.find("tbody").length == 0 ) {
        table.detach();
        this._addEmptyResultsP();
    }
};

R2.FormWidget.MemberSearch.prototype._addEmptyResultsP = function () {
    var p = $("<p/>");
    p.append( document.createTextNode("No members yet") );
    p.addClass("ajax-search-empty");
    p.attr( "id", "member-search-empty" );

    this.selected.append(p);
};

R2.FormWidget.MemberSearch.prototype._hideResults = function () {
    this.results_div.fadeOut(500);
};

R2.FormWidget.MemberSearch.prototype._handleEmptySubmitFunction = function () {
    var self = this;

    var func = function () {
        self._cleanResultsDiv();

        var text = "You must provide a name to search for.";
        self.results_div.append( document.createTextNode(text) );

        self.results_div.fadeIn(500);
    };

    return func;
};

R2.FormWidget.MemberSearch.prototype._handleErrorFunction = function (results) {
    var self = this;

    var func = function () {
        self._cleanResultsDiv();

        var text = "An error occurred when searching for matching people."
        text += " Sometimes this error is temporary, so feel free to try again."
        text += " If this error persists, please contact support.";

        self.results_div.append( document.createTextNode(text) );
    };

    return func;
};
