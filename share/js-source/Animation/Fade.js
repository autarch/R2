JSAN.use("DOM.Ready");


if ( typeof Animation == "undefined" ) { Animation = {}; }

Animation.Fade = function (params) {
    this._initialize(params);
};

Animation.Fade.DEBUG = 0;
Animation.Fade.VERSION = "0.10";

Animation.Fade.DEFAULT_FRAMES = 20;
Animation.Fade.DEFAULT_DURATION = 500;

Animation.Fade.fade = function (params) {
    new Animation.Fade(params);
};

Animation.Fade.prototype._initialize = function (params) {
    this._setParams(params);

    var self = this;
    DOM.Ready.onIdReady( params.elementId,
                         function (elt) { self._startFade(elt); }
                       );
};

Animation.Fade.prototype._setParams = function (params) {
    if ( ! params.elementId ) {
        throw new Error("Animation.Resize requires an elementId parameter");
    }

    if ( typeof params.targetOpacity == "undefined" ) {
        throw new Error("Animation.Fade requires a targetOpacity parameter");
    }

    if ( params.targetOpacity < 0 || params.targetOpacity > 1 ) {
        throw new Error("targetOpacity must be a number from 0 to 1");
    }

    this._targetOpacity  = params.targetOpacity;
    this._onFinish  = params.onFinish;

    this._frameCount = params.frameCount;
    this._totalDuration = params.totalDuration;

    if ( typeof this._frameCount == "undefined" ) {
        this._frameCount = Animation.Fade.DEFAULT_FRAMES;
    }

    if ( typeof this._totalDuration == "undefined" ) {
        this._totalDuration = Animation.Fade.DEFAULT_DURATION;
    }

    this._intervalDuration =
        this._totalDuration / this._frameCount;
};

Animation.Fade.prototype._startFade = function (elt) {
    if ( Animation.Fade.DEBUG ) {
        alert( "Fading: #" + elt.id
               + "\n"
               + "opacity: " + this._targetOpacity );
    }

    this._elt = elt;

    this._calcInitialOpacity();
    this._calcFrames();

    var self = this;
    this._interval =
        setInterval( function () {
            self._doFrame();
        }, this._intervalDuration );
};

Animation.Fade.prototype._calcFrames = function () {
    var frames = [];

    var step_size = ( this._targetOpacity - this._currentOpacity ) / this._frameCount;

    for ( var i = 0; i < this._frameCount; i++ ) {
        frames.push( { "opacity": step_size } );
    }

    this._frames = frames;
};

Animation.Fade.prototype._calcInitialOpacity = function () {
    this._currentOpacity = parseFloat( this._elt.style.opacity );
};

Animation.Fade.prototype._doFrame = function () {
    if ( this._frames.length ) {
        this._applyStep( this._frames.shift() );

        if ( this._isLastFrame() ) {
            this._finish();
        }
    }
};

Animation.Fade.prototype._applyStep = function (step) {
    this._currentOpacity += step.opacity;

    if ( this._currentOpacity < 0 ) {
        this._currentOpacity = 0;
    }
    else if ( this._currentOpacity > 1 ) {
        this._currentOpacity = 1;
    }

    this._elt.style.opacity = this._currentOpacity;

    if ( Animation.Fade.DEBUG ) {
        alert( "Set opacity of: #" + this._elt.id
               + "\n"
               + "to: " + this._currentOpacity );
    }
};

Animation.Fade.prototype._isLastFrame = function () {
    if ( this._frames.length ) {
        return false;
    }
    else {
        return true;
    }
};

Animation.Fade.prototype._finish = function () {
    this._clearInterval();
    if ( this._onFinish ) {
        this._onFinish();
    }
};

Animation.Fade.prototype.cancel = function () {
    this._clearInterval();
};

Animation.Fade.prototype._clearInterval = function () {
    clearInterval( this._interval );
};
