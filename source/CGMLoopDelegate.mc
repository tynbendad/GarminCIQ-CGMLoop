/*
 * CGM Loop Garmin Connect IQ application
 * Copyright (C) 2017 tynbendad@gmail.com
 * #WeAreNotWaiting
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3 of the License.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   A copy of the GNU General Public License is available at
 *   https://www.gnu.org/licenses/gpl-3.0.txt
 */
 
using Toybox.WatchUi as Ui;
using Toybox.Application as App;

class CGMLoopDelegate extends Ui.InputDelegate {

    // Handle key  events
    function onKey(evt) {
        var app = App.getApp();
        var key = evt.getKey();
        if (Ui.KEY_DOWN == key) {
            app.myView.incIndex();
        } else if (Ui.KEY_UP == key) {
            app.myView.decIndex();
        } else if (Ui.KEY_ENTER == key) {
            app.myView.action();
        } else if (Ui.KEY_START == key) {
            app.myView.action();
        } else {
            return false;
        }
        Ui.requestUpdate();
        return true;
    }

    // Handle touchscreen taps
    function onTap(evt) {
        var app = App.getApp();
        if (Ui.CLICK_TYPE_TAP == evt.getType()) {
            var coords = evt.getCoordinates();
            app.myView.setIndexFromYVal(coords[1]);
            Ui.requestUpdate();
            app.myView.action();
        }
        return true;
    }

    // Handle enter events
    function onSelect() {
        App.getApp().myView.action();
    }

    // Handle swipe events
    function onSwipe(evt) {
        var direction = evt.getDirection();
        if (Ui.SWIPE_DOWN == direction) {
            App.getApp().myView.incIndex();
        } else if (Ui.SWIPE_UP == direction) {
            App.getApp().myView.decIndex();
        } else if (Ui.SWIPE_LEFT == direction) {
            App.getApp().myView.decIndex();
        } else if (Ui.SWIPE_RIGHT == direction) {
            App.getApp().myView.incIndex();
        }
        Ui.requestUpdate();
    }

}
