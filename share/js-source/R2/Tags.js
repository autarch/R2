if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Tags = function () {
    var form = $("#tags-form");

    if ( ! form.length ) {
        return;
    }

    this._form = form;
    this._input = this._form.find('input[name="tags"]');

    this._instrumentForm();
    this._instrumentDeleteURIs();
};

R2.Tags.prototype._instrumentForm = function () {
    var self = this;

    this._form.submit(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self._submitForm();
        }
    );
};

R2.Tags.prototype._submitForm = function () {
    var tags = this._input.val();

    if ( ! ( tags && tags.length ) ) {
        return;
    }

    var self = this;

    $.ajax(
        {
            "url":      this._form.attr("action"),
            "type":     "POST",
            "data":     { "tags": tags },
            "dataType": "json",
            "success" : function (data) { self._handleSuccess(data) },
            "error":    function ( xhr, status, error ) { self._handleFailure(xhr) }
        }
    );
};

R2.Tags.prototype._handleSuccess = function (data) {
    this._input.val("");
    this._updateTagList(data);
};

R2.Tags.prototype._handleFailure = function () {

};

R2.Tags.prototype._updateTagList = function (data) {
    var list = $("#tags-list");

    list.children().detach();

    for ( var i = 0; i < data.tags.length; i++ ) {
        var tag = data.tags[i];

        var img = $("<img/>");
        img.attr(
            "src",
            tag.is_email_list
                ? "/images/icons/mail-tag.png"
                : "/images/icons/tag.png"
        );

        var tag_a = $("<a/>");
        tag_a.attr( "href", tag.uri );
        tag_a.append( document.createTextNode( tag.tag ) );

        var delete_a = $("<a/>");
        delete_a.attr( "href", tag.delete_uri );
        delete_a.addClass("delete-tag");
        delete_a.append( document.createTextNode("x") );

        var li = $("<li/>");
        li.append(
            img,
            tag_a,
            document.createTextNode(" "),
            delete_a,
            document.createTextNode(" ")
        );

        list.append(li);
    }

    this._instrumentDeleteURIs();

    return;
};

R2.Tags.prototype._instrumentDeleteURIs = function () {
    var self = this;

    $("a.delete-tag").each(
        function () {
            $(this).click(
                function (e) {
                    e.preventDefault();
                    e.stopPropagation();

                    self._deleteTag( $(this).attr("href") );
                }
            );
        }
    );
};

R2.Tags.prototype._deleteTag = function (uri) {
    var self = this;

    $.ajax(
        {
            "url":      uri,
            "type":     "DELETE",
            "success" : function (data) { self._handleSuccess(data) },
        }
    );
};
