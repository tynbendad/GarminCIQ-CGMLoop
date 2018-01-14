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

using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;

class CGMLoopGoalView extends Ui.View {
    var goalString;
    var screenShape;

    function initialize(goal) {
    	System.println("in GoalView initialize");
        View.initialize();
        screenShape = Sys.getDeviceSettings().screenShape;

        goalString = "GOAL!";

        if(goal == App.GOAL_TYPE_STEPS) {
            goalString = "STEPS " + goalString;
        }
        else if(goal == App.GOAL_TYPE_FLOORS_CLIMBED) {
            goalString = "STAIRS " + goalString;
        }
        else if(goal == App.GOAL_TYPE_ACTIVE_MINUTES) {
            goalString = "ACTIVE " + goalString;
        }
    	System.println("out GoalView initialize");
    }

    function onLayout(dc) {
    }

    function onShow() {
    }

    function onUpdate(dc) {
        var width;
        var height;
        var clockTime = Sys.getClockTime();

        width = dc.getWidth();
        height = dc.getHeight();

        var now = Time.now();
        var info = Calendar.info(now, Time.FORMAT_LONG);

        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        dc.fillRectangle(0, 0, width, height);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
        dc.fillPolygon([[0, 0], [width, 0], [width, height], [0, 0]]);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height / 4), Gfx.FONT_MEDIUM, dateStr, Gfx.TEXT_JUSTIFY_CENTER);

        dc.drawText(width / 2, (height / 2), Gfx.FONT_MEDIUM, goalString, Gfx.TEXT_JUSTIFY_CENTER);
    }
}
