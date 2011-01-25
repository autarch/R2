JSAN.use('R2.FormWidget.AjaxSearch');
JSAN.use('R2.Utils');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.ContactSearch = function () {
    var search_div = $("#contact-search");

    if ( ! search_div.length ) {
        return;
    }

    this.form           = search_div.closest("form");
    this.uri            = $("#JS-contact-search-uri").val();
    this.results_div    = $("#contact-search-results");
    this.selected_input = $('input[name="dedicated_to_contact_id"]');
    this.name_input     = $('input[name="dedicated_to"]');
    this.contact_id     = this.selected_input.val();

    this._instrumentResultsClose();
    this._instrumentContactSearch();
};

R2.FormWidget.ContactSearch.prototype._instrumentResultsClose = function () {
    var self = this;

    $("#contact-search-results-close").click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self._hideResults();
        }
    );
};

R2.FormWidget.ContactSearch.prototype._instrumentContactSearch = function () {
    new R2.FormWidget.AjaxSearch(
        this.uri,
        "contact",
        this._onSearchSubmitFunction(),
        this._handleEmptySubmitFunction(),
        this._populateResultsFunction(),
        this._handleErrorFunction()
    );
};

R2.FormWidget.ContactSearch.prototype._onSearchSubmitFunction = function () {
    var self = this;

    var func = function () {
        self._cleanResultsDiv();

        self.results_div.append( document.createTextNode("Searching ...") );

        self.results_div.fadeIn(500);
    };

    return func;
};

R2.FormWidget.ContactSearch.prototype._populateResultsFunction = function () {
    var self = this;

    var func = function (results) {
        self._cleanResultsDiv();

        if ( results.length > 0 ) {
            var text = "Found " + results.length;
            text += results.length == 1 ? " match:" : " matches:";

            self.results_div.append( document.createTextNode(text) );

            var table = self._createResultsTable();
            table.addClass("ajax-search-results-table");
            table.attr( "id", "contact-search-results-table" );

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

R2.FormWidget.ContactSearch.prototype._cleanResultsDiv = function () {
    this.results_div.contents().filter(
        function () {
            if ( $(this).attr("id") == "contact-search-results-close"
                 || $(this).find("#contact-search-results-close").length ) {
                return 0;
            }

            return 1;
        }
    ).remove();
};

R2.FormWidget.ContactSearch.prototype._createResultsTable = function () {
    var table = $("<table/>");

    var thead = $("<thead/>");

    var tr = $("<tr/>");

    var name_th = $("<th/>");
    name_th.append( document.createTextNode("Name") );
    name_th.addClass("name");

    tr.append(name_th);

    var button_th = $("<th/>");
    button_th.addClass("button");

    tr.append(button_th);

    thead.append(tr);

    table.append(thead);

    table.append( $("<tbody/>") );

    return table;
};

R2.FormWidget.ContactSearch.prototype._createResultRow = function (result) {
    var tr = $("<tr/>");

    var id = R2.Utils.makeUniqueId();
    result.id = id;

    var name_td = $("<td/>");
    name_td.append( document.createTextNode( result.display_name ) );
    name_td.addClass(name);

    tr.append(name_td);

    if ( this.contact_id == result.contact_id ) {
        var already_td = $("<td/>");
        already_td.append( document.createTextNode("Currently selected") );

        tr.append(already_td);
    }
    else {
        var adder_td = $("<td/>");
        adder_td.addClass("button");

        var adder = $("<button/>");
        adder.attr( "type", "button" );
        adder.attr( "id",   "adder-" + id );
        adder.append( document.createTextNode("select") );

        adder.click(
            this._selectContactFunction(result)
        );

        adder_td.append(adder);

        tr.append(adder_td);
    }

    return tr;
};

R2.FormWidget.ContactSearch.prototype._selectContactFunction = function (res) {
    var result = res;
    var self = this;

    var func = function (e) {
        e.preventDefault();
        e.stopPropagation();

        self._hideResults();

        self.contact_id = result.contact_id;

        self.selected_input.val( result.contact_id );
        self.name_input.val( result.display_name );
    };

    return func;
};

R2.FormWidget.ContactSearch.prototype._positionEnterFunction = function (button) {
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

R2.FormWidget.ContactSearch.prototype._removeSelectedTr = function (tr) {
    var table = tr.closest("table");

    tr.closest("tbody").detach();

    if ( table.find("tbody").length == 0 ) {
        table.detach();
        this._addEmptyResultsP();
    }
};

R2.FormWidget.ContactSearch.prototype._addEmptyResultsP = function () {
    var p = $("<p/>");
    p.append( document.createTextNode("No members yet") );
    p.addClass("contact-search-empty");
    p.attr( "id", "contact-search-empty" );

    this.selected.append(p);
};

R2.FormWidget.ContactSearch.prototype._hideResults = function () {
    this.results_div.fadeOut(500);
};

R2.FormWidget.ContactSearch.prototype._handleEmptySubmitFunction = function () {
    var self = this;

    var func = function () {
        self._cleanResultsDiv();

        var text = "You must provide a name to search for.";
        self.results_div.append( document.createTextNode(text) );

        self.results_div.fadeIn(500);
    };

    return func;
};

R2.FormWidget.ContactSearch.prototype._handleErrorFunction = function (results) {
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
