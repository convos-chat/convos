/*
* jQuery Mobile Framework 1.1.0 db342b1f315c282692791aa870455901fdb46a55
* http://jquerymobile.com
*
* Copyright 2011 (c) jQuery Project
* Dual licensed under the MIT or GPL Version 2 licenses.
* http://jquery.org/license
*
*/

/*
* Stripped the touch swipe logic from jQuery Mobile and turned it into this plugin
* Copyright 2012 (c) CodingJack - http://codecanyon.net/user/CodingJack
* Dual licensed under the MIT or GPL Version 2 licenses.
*/

/* USAGE

// listen both left and right signals, the String "left" or "right" will be passed as an argument to the callback
* $(element).touchSwipe(callback);

// second parameter is optional and will invoke "event.stopImmediatePropagation()"
// use this if you need to prevent other mouse events from firing on the same object when a swipe gesture is detected
* $(element).touchSwipe(callback, true);

// listen for only the left swipe event
* $(element).touchSwipeLeft(callback);

// listen for only the right swipe event
* $(element).touchSwipeRight(callback);

// unbind both left and right swipe events
* $(element).unbindSwipe();

// unbind only left swipe event
* $(element).unbindSwipeLeft();

// unbind only right swipe event
* $(element).unbindSwipeRight();


// SPECIAL NOTES
* all methods return "this" for chaining
* before a plugin event is added, "unbind" is called first to make sure events are never erroneously duplicated

*/

;(function($) {
  var touchStopEvent, touchMoveEvent, touchStartEvent,
  horizontalDistanceThreshold = 30,
  verticalDistanceThreshold = 75,
  scrollSupressionThreshold = 10,
  durationThreshold = 1000;

  if("ontouchend" in document) {
    touchStopEvent = "touchend.cj_swp";
    touchMoveEvent = "touchmove.cj_swp";
    touchStartEvent = "touchstart.cj_swp";

  }
  else {
    touchStopEvent = "mouseup.cj_swp";
    touchMoveEvent = "mousemove.cj_swp";
    touchStartEvent = "mousedown.cj_swp";
  }

  $.fn.touchSwipe = function(cb, prevent) {
    if(prevent) this.data("stopPropagation", true);
    if(cb) return this.each(swipeBoth, [cb]);
  };
  $.fn.touchSwipeLeft = function(cb, prevent) {
    if(prevent) this.data("stopPropagation", true);
    if(cb) return this.each(swipeLeft , [cb]);
  };
  $.fn.touchSwipeRight = function(cb, prevent) {
    if(prevent) this.data("stopPropagation", true);
    if(cb) return this.each(swipeRight, [cb]);
  };

  function swipeBoth(cb) {
    $(this).touchSwipeLeft(cb).touchSwipeRight(cb);
  }
  function swipeLeft(cb) {
    var $this = $(this);
    if(!$this.data("swipeLeft")) $this.data("swipeLeft", cb);
    if(!$this.data("swipeRight")) addSwipe($this);
  }
  function swipeRight(cb) {
    var $this = $(this);
    if(!$this.data("swipeRight")) $this.data("swipeRight", cb);
    if(!$this.data("swipeLeft")) addSwipe($this);
  }
  $.fn.unbindSwipeLeft = function() {
    this.removeData("swipeLeft");
    if(!this.data("swipeRight")) this.unbindSwipe(true);
  };
  $.fn.unbindSwipeRight = function() {
    this.removeData("swipeRight");
    if(!this.data("swipeLeft")) this.unbindSwipe(true);
  };
  $.fn.unbindSwipe = function(changeData) {
    if(!changeData) this.removeData("swipeLeft swipeRight stopPropagation");
    return this.unbind(touchStartEvent + " " + touchMoveEvent + " " + touchStopEvent);
  };
  function addSwipe($this) {
    $this.unbindSwipe(true).bind(touchStartEvent, touchStart);
  }
  function touchStart(event) {
    var time = new Date().getTime(),
    data = event.originalEvent.touches ? event.originalEvent.touches[0] : event,
    $this = $(this).bind(touchMoveEvent, moveHandler).one(touchStopEvent, touchEnded),
    pageX = data.pageX,
    pageY = data.pageY,
    newPageX,
    newPageY,
    newTime;

    if($this.data("stopPropagation")) event.stopImmediatePropagation();

    function touchEnded(event) {
      $this.unbind(touchMoveEvent);

      if(time && newTime) {
        if(newTime - time < durationThreshold && Math.abs(pageX - newPageX) > horizontalDistanceThreshold && Math.abs(pageY - newPageY) < verticalDistanceThreshold) {
          if(pageX > newPageX) {
            if($this.data("swipeLeft")) $this.data("swipeLeft")("left");
          }
          else {
            if($this.data("swipeRight")) $this.data("swipeRight")("right");
          }
        }
      }

      time = newTime = null;
    }

    function moveHandler(event) {
      if(time) {
        data = event.originalEvent.touches ? event.originalEvent.touches[0] : event;
        newTime = new Date().getTime();
        newPageX = data.pageX;
        newPageY = data.pageY;

        if(Math.abs(pageX - newPageX) > scrollSupressionThreshold) event.preventDefault();
      }
    }
  }
})(jQuery);
