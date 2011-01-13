/*

*/

if ( typeof( DOM ) == 'undefined' ) {
    DOM = {};
}

/*

*/

document.getElementsByClass = function(className) {
    var children = document.getElementsByTagName('*') || document.all;
    var elements = new Array();

    for (var i = 0; i < children.length; i++) {
        var child = children[i];
        var classNames = child.className.split(' ');
        for (var j = 0; j < classNames.length; j++) {
            if (classNames[j] == className) {
              elements.push(child);
              break;
            }
        }
    }

    return elements;
};
document.getElementsByClassName = document.getElementsByClass;

/*

*/
