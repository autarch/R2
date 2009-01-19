JSAN.use('DOM.Element');
JSAN.use('Widget.PairedMultiSelect');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.PairedMultiSelect = function (params) {
    this.superclass(params);
    this._resize_selects();
};

R2.FormWidget.PairedMultiSelect.prototype = Widget.PairedMultiSelect.prototype;

R2.FormWidget.PairedMultiSelect.prototype.superclass = Widget.PairedMultiSelect;

R2.FormWidget.PairedMultiSelect._sortByText = function ( a, b ) {
    if ( a.text < b.text ) return -1;
    if ( a.text > b.text ) return  1;
                           return  0;

};

R2.FormWidget.PairedMultiSelect.newFromPrefix = function (prefix, sortFunction) {
    return new R2.FormWidget.PairedMultiSelect
        ( { firstId: prefix + "-first",
            secondId: prefix + "-second",
            selectedFirstToSecondId: prefix + "-to-second",
            selectedSecondToFirstId: prefix + "-to-first",
            allFirstToSecond: prefix + "-all-to-second",
            allSecondToFirstId: prefix + "-all-to-first",
            sortFunction: R2.FormWidget.PairedMultiSelect._sortByText
          }
        );
};

R2.FormWidget.PairedMultiSelect.prototype._resize_selects = function () {
    var context_elt = this.first.parentNode;

    var longest_string = "";

    for ( var i = 0; i < this.first.options.length; i++ ) {
        if ( this.first.options[i].text.length > longest_string.length ) {
            longest_string = this.first.options[i].text;
        }
    }

    for ( var i = 0; i < this.second.options.length; i++ ) {
        if ( this.second.options[i].text.length > longest_string.length ) {
            longest_string = this.second.options[i].text;
        }
    }

    if ( longest_string.length ) {
        var text = document.createTextNode(longest_string);
        var span = document.createElement("span");
        span.appendChild(text);

        var option = this.first.options.length ? this.first.options[0] : this.second.options[0];

        if (option) {
            var styles;

            var multiplier = 1.08;
            /* IE */
            if ( option.currentStyle ) {
                styles = option.currentStyle;
                multiplier = 1.2;
            }
            /* Safari */
            else if ( option.style ) {
                styles = option.style;
            }
            /* FF */
            else {
                styles = document.defaultView.getComputedStyle( option, null );
            }

            span.fontFamily = styles.getPropertyValue("font-family");
            span.fontWeight = styles.getPropertyValue("font-weight");
            span.fontSize = styles.getPropertyValue("font-size");
        }

        /* The element has to actually be in the document or it will
           not have an offsetWidth */
        context_elt.appendChild(span);

        var width = span.offsetWidth * multiplier;
        context_elt.removeChild(span);

        this.first.style.width = width + "px";
        this.second.style.width = width + "px";
    }
};
